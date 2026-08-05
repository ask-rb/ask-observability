# frozen_string_literal: true

require_relative 'test_helper'
require 'opentelemetry-sdk'
require 'opentelemetry-exporter-otlp'

class BootstrapTest < Minitest::Test
  def setup
    @previous_config = Ask::Observability.instance_variable_get(:@config)
    Ask::Observability.instance_variable_set(:@config, Ask::Observability::Configuration.new)
    Ask::Observability::Bootstrap.instance_variable_set(:@otel_installed, false)
  end

  def teardown
    Ask::Observability.instance_variable_set(:@config, @previous_config)
    Ask::Observability::Bootstrap.instance_variable_set(:@otel_installed, false)
    remove_fake_rails
    return unless @_ask_rails_shadow && Ask.const_defined?(:Rails)

    Ask.send(:remove_const, :Rails)
  end

  def remove_fake_rails
    return unless defined?(@_fake_rails) && Object.const_defined?(:Rails) && Object.const_get(:Rails) == @_fake_rails

    Object.send(:remove_const, :Rails)
  end

  # --- OpenTelemetry -----------------------------------------------------

  def test_install_otel_configures_sdk_with_service_name_and_endpoint
    configured = nil
    OpenTelemetry::SDK.stub(:configure, ->(&block) { configured = block }) do
      Ask::Observability.config.service_name = 'my-app'
      Ask::Observability.config.otlp_endpoint = 'http://collector:4318/v1/traces'
      Ask::Observability::Bootstrap.install_otel
    end

    assert configured, 'SDK.configure was never called'
    # The configure block must set service_name when the SDK runs it.
    fake = FakeSdkConfig.new
    configured.call(fake)

    assert_equal 'my-app', fake.service_name
  end

  def test_install_otel_skips_when_otl_disabled
    ENV['OTEL_DISABLED'] = 'true'
    called = false
    OpenTelemetry::SDK.stub(:configure, ->(&_) { called = true }) do
      Ask::Observability::Bootstrap.install_otel
    end

    refute called
  ensure
    ENV.delete('OTEL_DISABLED')
  end

  def test_install_otel_skips_in_test_environment
    @_fake_rails = Module.new
    env = Object.new
    env.define_singleton_method(:test?) { true }
    @_fake_rails.define_singleton_method(:env) { env }
    Object.const_set(:Rails, @_fake_rails)

    called = false
    OpenTelemetry::SDK.stub(:configure, ->(&_) { called = true }) do
      Ask::Observability::Bootstrap.install_otel
    end

    refute called
  end

  def test_install_otel_skips_in_test_environment_with_ask_rails_shadowing
    # ask-rails defines Ask::Rails; inside Ask::* the bare constant would
    # resolve to it. The guards must use ::Rails regardless.
    shadow = Module.new
    Ask.const_set(:Rails, shadow)
    @_ask_rails_shadow = true
    @_fake_rails = Module.new
    env = Object.new
    env.define_singleton_method(:test?) { true }
    @_fake_rails.define_singleton_method(:env) { env }
    Object.const_set(:Rails, @_fake_rails)

    called = false
    OpenTelemetry::SDK.stub(:configure, ->(&_) { called = true }) do
      Ask::Observability::Bootstrap.install_otel
    end

    refute called, 'Ask::Rails must not shadow ::Rails in the guards'
  end

  def test_install_otel_is_idempotent
    calls = 0
    OpenTelemetry::SDK.stub(:configure, ->(&_) { calls += 1 }) do
      2.times { Ask::Observability::Bootstrap.install_otel }
    end

    assert_equal 1, calls
  end

  def test_install_otel_rescues_and_warns_on_failure
    OpenTelemetry::SDK.stub(:configure, ->(&_) { raise 'boom' }) do
      _out, err = capture_io { Ask::Observability::Bootstrap.install_otel }

      assert_includes err, '[ask-observability]'
    end
  end

  def test_service_name_defaults_to_rails_app_name
    @_fake_rails = Module.new
    app = Object.new
    app.define_singleton_method(:class) do
      Class.new { def self.module_parent_name = 'MyGreatApp' }
    end
    @_fake_rails.define_singleton_method(:application) { app }
    Object.const_set(:Rails, @_fake_rails)

    assert_equal 'my_great_app', Ask::Observability::Bootstrap.service_name
  end

  def test_service_name_falls_back_without_rails
    assert_equal 'ask-app', Ask::Observability::Bootstrap.service_name
  end

  # --- JSON logging ------------------------------------------------------

  def test_install_json_logging_adds_stdout_appender
    fake_rails = fake_rails_with_logging_config(configured: false)
    captured = nil

    app = fake_rails.application
    app.config.rails_semantic_logger.define_singleton_method(:appenders) do |&block|
      captured = block
    end

    Ask::Observability::Bootstrap.install_json_logging

    assert captured, 'expected appenders DSL block to be registered'
    fake_appenders = Object.new
    added = []
    fake_appenders.define_singleton_method(:add) { |**opts| added << opts }
    captured.call(fake_appenders)

    assert_equal :json, added.first[:formatter]
    assert_equal $stdout, added.first[:io]
  end

  def test_install_json_logging_skips_when_appenders_configured
    fake_rails = fake_rails_with_logging_config(configured: true)
    app = fake_rails.application
    called = false
    app.config.rails_semantic_logger.define_singleton_method(:appenders) { |&_| called = true }

    Ask::Observability::Bootstrap.install_json_logging

    refute called, 'must not touch appenders the host app already configured'
  end

  def test_install_json_logging_skips_when_disabled
    Ask::Observability.config.json_logging = false
    fake_rails = fake_rails_with_logging_config(configured: false)
    options = fake_rails.application.config.rails_semantic_logger

    Ask::Observability::Bootstrap.install_json_logging

    # The appenders DSL was never invoked (it would raise on our fake).
    refute_respond_to options, :appenders
  end

  def test_install_json_logging_skips_without_rails
    # No Rails constant: must no-op without raising.
    assert_nil Ask::Observability::Bootstrap.install_json_logging
  end

  def test_install_json_logging_uses_real_rails_with_ask_rails_shadowing
    # Ask::Rails (ask-rails) must not shadow ::Rails in the guard.
    shadow = Module.new
    Ask.const_set(:Rails, shadow)
    @_ask_rails_shadow = true
    fake_rails = fake_rails_with_logging_config(configured: false)
    captured = nil

    app = fake_rails.application
    app.config.rails_semantic_logger.define_singleton_method(:appenders) do |&block|
      captured = block
    end

    Ask::Observability::Bootstrap.install_json_logging

    assert captured, 'expected appenders DSL block to be registered despite Ask::Rails'
  end

  private

  # Builds: Rails.application.config.rails_semantic_logger with a given
  # appenders? answer.
  def fake_rails_with_logging_config(configured:)
    options = Object.new
    options.define_singleton_method(:appenders?) { configured }
    config = Object.new
    config.instance_variable_set(:@semantic_logger_options, options)
    config.define_singleton_method(:rails_semantic_logger) do
      @semantic_logger_options
    end
    app = Object.new
    app.instance_variable_set(:@config, config)
    app.define_singleton_method(:config) { @config }
    @_fake_rails = Module.new
    @_fake_rails.define_singleton_method(:application) { app }
    Object.const_set(:Rails, @_fake_rails)
    @_fake_rails
  end

  # Minimal stand-in for the OTel SDK configure block receiver.
  class FakeSdkConfig
    attr_accessor :service_name

    def add_span_processor(*) end

    def use_all(*) end
  end
end
