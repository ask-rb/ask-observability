# frozen_string_literal: true

module Ask
  module Observability
    # Turns Ask::Instrumentation events into Prometheus metrics:
    #
    #   ask_llm_calls_total{provider,model,kind}
    #   ask_llm_tokens_total{provider,model,kind,direction}
    #   ask_llm_duration_seconds{provider,model,kind}
    #   ask_llm_errors_total{provider,kind}
    #
    # Metadata attached via Ask::Instrumentation.with_metadata is merged
    # into every event payload, so configured metadata keys (see
    # Configuration#label_metadata) are read straight off the payload —
    # missing values render as "unknown".
    class Subscriber
      # Event name → metric kind (mirrors ask-opentelemetry's span map).
      KIND_BY_EVENT = {
        'chat.ask' => 'chat',
        'chat.stream.ask' => 'chat',
        'tool.ask' => 'tool',
        'embedding.ask' => 'embedding',
        'image.ask' => 'image'
      }.freeze

      # Invoked by ActiveSupport::Notifications for each matching event.
      #
      # @param event [ActiveSupport::Notifications::Event]
      def call(event)
        kind = KIND_BY_EVENT[event.name]
        return unless kind

        payload = event.payload
        metrics = Ask::Observability.metrics
        labels = base_labels(payload, kind).merge(metadata_labels(payload))

        metrics.calls_total.increment(labels: labels)
        metrics.duration_seconds.observe(event.duration / 1000.0, labels: labels)
        record_tokens(metrics, labels, payload)
        record_error(metrics, labels, payload) if payload[:error]
      end

      private

      def base_labels(payload, kind)
        {
          provider: stringify(payload[:provider]),
          model: stringify(payload[:model]),
          kind: kind
        }
      end

      def record_tokens(metrics, labels, payload)
        input = payload[:input_tokens].to_i
        output = payload[:output_tokens].to_i
        return if input.zero? && output.zero?

        metrics.tokens_total.increment(by: input, labels: labels.merge(direction: 'input')) if input.positive?
        metrics.tokens_total.increment(by: output, labels: labels.merge(direction: 'output')) if output.positive?
      end

      def record_error(metrics, labels, _payload)
        metrics.errors_total.increment(labels: labels.except(:model))
      end

      # Configured metadata keys present in the payload, as label values.
      def metadata_labels(payload)
        Ask::Observability.config.metadata_label_keys.to_h do |key|
          [key, stringify(payload[key])]
        end
      end

      # Prometheus label values must be strings; absent values become
      # "unknown" so the series stays addressable.
      def stringify(value)
        value.to_s.empty? ? 'unknown' : value.to_s
      end
    end
  end
end
