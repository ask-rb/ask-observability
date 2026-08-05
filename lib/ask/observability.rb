# frozen_string_literal: true

require 'ask/instrumentation'
require 'prometheus/client'
require 'prometheus/client/formats/text'

require_relative 'observability/version'

# Rails discovers gem railties only when they are required, so load the
# railtie from the entry file once Rails itself is on the stack (the
# documented pattern: "require my_gem/railtie if defined?(Rails::Railtie)").
require_relative 'observability/railtie' if defined?(Rails::Railtie)

module Ask
  # Ask::Observability — Prometheus metrics, OpenTelemetry bootstrap, and
  # structured logging for the ask-rb ecosystem.
  #
  # The ask-rb observability story composes:
  #   * ask-instrumentation   — emits events for every LLM operation
  #   * ask-opentelemetry     — events → OpenTelemetry spans
  #   * ask-observability     — events → Prometheus metrics, plus the
  #                             OTel/logging bootstrap and /metrics
  #   * ask-monitoring        — events → in-app dashboard + alerts
  #
  # == Usage
  #
  #   Ask::Observability.install
  #
  # In a Rails app the railtie auto-installs (bootstrap + subscriber +
  # /metrics); configure it first:
  #
  #   Ask::Observability.configure do |config|
  #     config.service_name = "my-app"
  #     config.label_metadata = [:workspace_id]
  #   end
  module Observability
    autoload :Bootstrap, 'ask/observability/bootstrap'
    autoload :Configuration, 'ask/observability/configuration'
    autoload :Metrics, 'ask/observability/metrics'
    autoload :MetricsApp, 'ask/observability/metrics_app'
    autoload :Railtie, 'ask/observability/railtie'
    autoload :Subscriber, 'ask/observability/subscriber'

    class << self
      # The process-wide configuration. Configure before install (or
      # before the railtie runs) so metrics carry the final label set.
      #
      # @return [Configuration]
      def config
        @config ||= Configuration.new
      end

      # @yield [Configuration]
      def configure
        yield config
      end

      # The Prometheus registry backing every metric (and the /metrics
      # endpoint). Tests inject a fresh registry to isolate state.
      #
      # @return [Prometheus::Client::Registry]
      def registry
        @registry ||= Prometheus::Client::Registry.new
      end

      attr_writer :registry

      # Subscribe to every ask-instrumentation event and start maintaining
      # Prometheus metrics. Idempotent — subsequent calls are no-ops.
      def install
        return if installed?
        return if config.enabled == false

        @subscriber = Ask::Instrumentation.subscribe(/\.ask$/, Subscriber.new)
        @installed = true
      end

      # Remove the subscriber (tests use this to keep suites isolated).
      def uninstall
        return unless @subscriber

        Ask::Instrumentation.unsubscribe(@subscriber)
        @subscriber = nil
        @installed = false
      end

      # @return [Boolean] whether the subscriber is installed
      def installed?
        !!@installed
      end

      # Wrap a block so the given metadata flows into ask-instrumentation
      # events (and thus into spans and metrics) AND into Rails log lines
      # as tags, when Rails is present. One call to correlate a unit of
      # work — a request, a job, a call — everywhere.
      #
      # @param metadata [Hash] e.g. {call_id: "abc", workspace_id: 4}
      # @yield the block to run under the context
      # @return [Object] the block's return value
      def with_context(metadata, &block)
        Ask::Instrumentation.with_metadata(metadata) do
          if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger.respond_to?(:tagged)
            ::Rails.logger.tagged(**metadata, &block)
          else
            yield
          end
        end
      end

      # The metric definitions for the current registry.
      #
      # @return [Metrics]
      def metrics
        Metrics.for(registry, metadata_label_keys: config.metadata_label_keys)
      end
    end
  end
end
