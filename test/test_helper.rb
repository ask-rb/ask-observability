# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'ask/observability'

module ObservabilityTestHelpers
  # Isolate every test: a fresh registry, fresh metrics, a clean config and
  # an unsubscribed subscriber so nothing leaks across tests.
  def setup_observability
    Ask::Observability.uninstall
    Ask::Observability.registry = Prometheus::Client::Registry.new
    Ask::Observability::Metrics.reset!
    @previous_config = Ask::Observability.instance_variable_get(:@config)
    Ask::Observability.instance_variable_set(:@config, Ask::Observability::Configuration.new)
  end

  def teardown_observability
    Ask::Observability.uninstall
    Ask::Observability.instance_variable_set(:@config, @previous_config)
    Ask::Observability.registry = Prometheus::Client::Registry.new
    Ask::Observability::Metrics.reset!
  end

  # Emit an ask-instrumentation event, exactly like ask-agent does.
  def instrument(name, payload = {})
    Ask::Instrumentation.instrument(name, payload) { yield if block_given? }
  end
end
