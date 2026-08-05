# frozen_string_literal: true

require_relative 'test_helper'

class RailtieTest < Minitest::Test
  def setup
    # Stub Rails for railtie loading (mirrors ask-opentelemetry's test).
    unless defined?(::Rails)
      railtie = Class.new do
        def self.initializer(name) end
      end
      @_rails_stub = Module.new
      @_rails_stub.const_set(:Railtie, railtie)
      Object.const_set(:Rails, @_rails_stub)
    end
    require 'ask/observability/railtie'
  end

  def teardown
    return unless @_rails_stub && Object.const_defined?(:Rails) && Object.const_get(:Rails) == @_rails_stub

    Object.send(:remove_const, :Rails)
  end

  def test_railtie_is_defined
    assert Ask::Observability::Railtie
  end

  def test_railtie_file_exists
    path = File.expand_path('../lib/ask/observability/railtie.rb', __dir__)

    assert_path_exists path
  end

  def test_railtie_bootstraps_and_installs
    railtie_path = File.expand_path('../lib/ask/observability/railtie.rb', __dir__)
    content = File.read(railtie_path)

    assert_includes content, 'Ask::Observability::Bootstrap.install'
    assert_includes content, 'Ask::Observability.install'
  end

  def test_railtie_mounts_metrics_at_configured_path
    railtie_path = File.expand_path('../lib/ask/observability/railtie.rb', __dir__)
    content = File.read(railtie_path)

    assert_includes content, 'Ask::Observability::MetricsApp'
    assert_includes content, 'metrics_path'
  end

  def test_railtie_honors_enabled_flag
    railtie_path = File.expand_path('../lib/ask/observability/railtie.rb', __dir__)
    content = File.read(railtie_path)

    assert_includes content, 'enabled == false'
  end
end
