# frozen_string_literal: true

require 'active_support/core_ext/string/inflections'

module Ask
  module Observability
    # One-call runtime setup for a Rails app, mirroring what every
    # OpenTelemetry + structured-logging app hand-rolls:
    #
    #   * OpenTelemetry SDK wired to the OTLP collector (spans out),
    #     gated by OTEL_DISABLED and the test environment;
    #   * JSON structured logs on stdout via rails_semantic_logger (when
    #     that gem is present and the app hasn't configured appenders).
    #
    # The railtie calls +install+ automatically; everything can be disabled
    # through Configuration.
    module Bootstrap
      module_function

      # Installs both halves. Safe to call multiple times.
      def install
        install_otel
        install_json_logging
      end

      # Configure the global OpenTelemetry SDK once: batch span processor
      # exporting OTLP/HTTP to Configuration#otlp_endpoint, service name
      # from Configuration (or the Rails app name). The host app decides
      # which instrumentations to bundle (rack, rails, active_job, ...);
      # +use_all+ picks up whichever are installed.
      def install_otel
        return if @otel_installed
        return if ENV['OTEL_DISABLED'] == 'true'
        # ::Rails — inside Ask::*, the bare constant resolves to the sibling
        # Ask::Rails module when ask-rails is loaded.
        return if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env.test?

        require 'opentelemetry-sdk'
        require 'opentelemetry-exporter-otlp'

        # Absolute ::OpenTelemetry: from inside Ask::*, the bare constant
        # would resolve to Ask::OpenTelemetry (the sibling gem) first.
        ::OpenTelemetry::SDK.configure do |config|
          config.service_name = service_name
          config.add_span_processor(
            ::OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
              ::OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint: Ask::Observability.config.otlp_endpoint)
            )
          )
          config.use_all if defined?(::OpenTelemetry::Instrumentation::Rack)
        end
        @otel_installed = true
      rescue LoadError, StandardError => e
        warn "[ask-observability] OpenTelemetry bootstrap skipped: #{e.class}: #{e.message}"
      end

      # JSON appender on stdout — one line per record, shippable to any
      # log collector. Only applied when rails_semantic_logger is present
      # and the host app hasn't declared its own appenders.
      def install_json_logging
        return unless Ask::Observability.config.json_logging
        return unless defined?(::Rails) && ::Rails.respond_to?(:application)

        app = ::Rails.application
        options = app.config.rails_semantic_logger
        return unless options
        return if options.respond_to?(:appenders?) && options.appenders?

        app.config.rails_semantic_logger.appenders do |appenders|
          appenders.add(io: $stdout, formatter: :json)
        end
      end

      # service.name for spans: explicit config, else the Rails app name,
      # else a generic fallback.
      def service_name
        Ask::Observability.config.service_name || begin
          if defined?(::Rails) && ::Rails.respond_to?(:application) && ::Rails.application
            ::Rails.application.class.module_parent_name.to_s.underscore
          else
            'ask-app'
          end
        end
      end
    end
  end
end
