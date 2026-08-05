# frozen_string_literal: true

module Ask
  module Observability
    # Configuration for ask-observability. Set before the railtie runs
    # (config/initializers/ask_observability.rb) so the metrics are created
    # with their final label set — prometheus-client fixes a metric's label
    # keys at creation time.
    class Configuration
      # Master switch: when false, the subscriber, the OpenTelemetry
      # bootstrap, and the /metrics mount all no-op. Set in tests/CI to
      # keep output clean.
      attr_accessor :enabled

      # service.name for OpenTelemetry spans and logs. Defaults to the
      # Rails app name when running under Rails, else "ask-app".
      attr_accessor :service_name

      # OTLP/HTTP endpoint spans are exported to. Defaults to the local
      # collector (OpenObserve reference stack).
      attr_accessor :otlp_endpoint

      # Structured JSON logs on stdout via rails_semantic_logger (applied
      # when that gem is present and the app hasn't configured appenders).
      attr_accessor :json_logging

      # Mount path for the /metrics Rack endpoint; nil disables the mount
      # (a host app that serves its own /metrics can point this elsewhere
      # or nil and serve Ask::Observability.registry itself).
      attr_accessor :metrics_path

      # Metadata keys from Ask::Instrumentation.with_metadata to expose as
      # metric labels. WARNING: every distinct value creates a new series —
      # only use low-cardinality keys (workspace_id, org, tenant), never
      # per-request ids.
      attr_accessor :label_metadata

      def initialize
        @enabled = true
        @service_name = nil
        @otlp_endpoint = ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318/v1/traces')
        @json_logging = true
        @metrics_path = '/metrics'
        @label_metadata = []
      end

      # The configured metadata keys, normalized to symbols.
      #
      # @return [Array<Symbol>]
      def metadata_label_keys
        @label_metadata.map(&:to_sym)
      end
    end
  end
end
