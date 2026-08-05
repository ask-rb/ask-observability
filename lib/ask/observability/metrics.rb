# frozen_string_literal: true

module Ask
  module Observability
    # Prometheus metric definitions for ask-instrumentation events.
    #
    # Created lazily on a registry so gems/apps that never emit events don't
    # pay for registry entries, and so tests can inject a fresh registry.
    # The label set is fixed at creation (prometheus-client requires stable
    # label keys per metric) — hence the metadata keys must be configured
    # before the metrics are first touched.
    class Metrics
      # Label keys every metric carries.
      BASE_LABELS = %i[provider model kind].freeze

      class << self
        # Memoized per (registry, metadata keys) pair.
        def for(registry, metadata_label_keys: [])
          instances[[registry.object_id, metadata_label_keys]] ||=
            new(registry, metadata_label_keys: metadata_label_keys)
        end

        def instances
          @instances ||= {}
        end

        # For tests: forget every Metrics instance (fresh registries).
        def reset!
          instances.clear
        end
      end

      def initialize(registry, metadata_label_keys: [])
        @registry = registry
        @metadata_label_keys = metadata_label_keys
      end

      # ask_llm_calls_total{provider,model,kind}
      def calls_total
        @calls_total ||= @registry.counter(
          :ask_llm_calls_total,
          docstring: 'LLM calls by provider, model, and kind',
          labels: label_keys(:provider, :model, :kind)
        )
      end

      # ask_llm_tokens_total{provider,model,kind,direction}
      def tokens_total
        @tokens_total ||= @registry.counter(
          :ask_llm_tokens_total,
          docstring: 'LLM tokens by provider, model, kind, and direction',
          labels: label_keys(:provider, :model, :kind, :direction)
        )
      end

      # ask_llm_duration_seconds{provider,model,kind}
      def duration_seconds
        @duration_seconds ||= @registry.histogram(
          :ask_llm_duration_seconds,
          docstring: 'LLM call duration in seconds',
          labels: label_keys(:provider, :model, :kind),
          buckets: [0.1, 0.25, 0.5, 1, 2, 4, 8, 16, 32, 64]
        )
      end

      # ask_llm_errors_total{provider,kind}
      def errors_total
        @errors_total ||= @registry.counter(
          :ask_llm_errors_total,
          docstring: 'LLM calls that errored',
          labels: label_keys(:provider, :kind)
        )
      end

      private

      def label_keys(*keys)
        (keys + @metadata_label_keys).uniq
      end
    end
  end
end
