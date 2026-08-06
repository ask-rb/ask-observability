# frozen_string_literal: true

require_relative 'test_helper'

class SubscriberTest < Minitest::Test
  include ObservabilityTestHelpers

  def setup
    setup_observability
    Ask::Observability.install
  end

  def teardown
    teardown_observability
  end

  def registry
    Ask::Observability.registry
  end

  def calls(labels)
    registry.get(:ask_llm_calls_total).get(labels: labels)
  end

  def tokens(labels)
    registry.get(:ask_llm_tokens_total).get(labels: labels)
  end

  # --- calls counter -----------------------------------------------------

  def test_chat_event_increments_calls
    instrument('chat.ask', provider: 'openai', model: 'gpt-4')

    assert_equal 1, calls(provider: 'openai', model: 'gpt-4', kind: 'chat')
  end

  def test_stream_event_counts_as_chat
    instrument('chat.stream.ask', provider: 'openai', model: 'gpt-4')

    assert_equal 1, calls(provider: 'openai', model: 'gpt-4', kind: 'chat')
  end

  def test_tool_event_kind
    instrument('tool.ask', provider: 'openai', model: 'gpt-4', tool_name: 'get_weather')

    assert_equal 1, calls(provider: 'openai', model: 'gpt-4', kind: 'tool')
  end

  def test_embedding_event_kind
    instrument('embedding.ask', provider: 'openai', model: 'text-embedding-3')

    assert_equal 1, calls(provider: 'openai', model: 'text-embedding-3', kind: 'embedding')
  end

  def test_image_event_kind
    instrument('image.ask', provider: 'openai', model: 'dall-e-3')

    assert_equal 1, calls(provider: 'openai', model: 'dall-e-3', kind: 'image')
  end

  def test_unknown_event_is_ignored
    instrument('unknown.ask', provider: 'openai')

    assert_nil registry.get(:ask_llm_calls_total)
  end

  def test_missing_provider_and_model_become_unknown
    instrument('chat.ask')

    assert_equal 1, calls(provider: 'unknown', model: 'unknown', kind: 'chat')
  end

  def test_counter_accumulates
    3.times { instrument('chat.ask', provider: 'openai', model: 'gpt-4') }

    assert_equal 3, calls(provider: 'openai', model: 'gpt-4', kind: 'chat')
  end

  # --- tokens ------------------------------------------------------------

  def test_tokens_counted_by_direction
    instrument('chat.ask', provider: 'openai', model: 'gpt-4', input_tokens: 100, output_tokens: 50)

    assert_equal 100, tokens(provider: 'openai', model: 'gpt-4', kind: 'chat', direction: 'input')
    assert_equal 50, tokens(provider: 'openai', model: 'gpt-4', kind: 'chat', direction: 'output')
  end

  def test_token_events_without_tokens_create_no_series
    instrument('chat.ask', provider: 'openai', model: 'gpt-4')

    assert_nil registry.get(:ask_llm_tokens_total)
  end

  def test_zero_tokens_are_not_recorded
    instrument('chat.ask', provider: 'openai', model: 'gpt-4', input_tokens: 0, output_tokens: 0)

    assert_nil registry.get(:ask_llm_tokens_total)
  end

  def test_tokens_read_from_nested_usage_hash
    # ask-agent enriches a shared nested +usage+ hash after the call returns
    # (tokens are only known then); the subscriber must read from it.
    instrument('chat.ask', provider: 'openai', model: 'gpt-4',
               usage: { input_tokens: 100, output_tokens: 50 })

    assert_equal 100, tokens(provider: 'openai', model: 'gpt-4', kind: 'chat', direction: 'input')
    assert_equal 50, tokens(provider: 'openai', model: 'gpt-4', kind: 'chat', direction: 'output')
  end

  # --- duration ----------------------------------------------------------

  def test_duration_histogram_observes_seconds
    instrument('chat.ask', provider: 'openai', model: 'gpt-4') { sleep 0.05 }

    buckets = registry.get(:ask_llm_duration_seconds).get(labels: { provider: 'openai', model: 'gpt-4', kind: 'chat' })
    sum = buckets['sum']

    assert_operator sum, :>=, 0.04, "expected ~50ms observed as 0.05s, got #{sum}"
    assert_operator sum, :<, 1.0
  end

  # --- errors ------------------------------------------------------------

  def test_error_payload_increments_errors
    instrument('chat.ask', provider: 'openai', model: 'gpt-4', error: 'rate limited')

    assert_equal 1, registry.get(:ask_llm_errors_total).get(labels: { provider: 'openai', kind: 'chat' })
  end

  def test_success_payload_does_not_increment_errors
    instrument('chat.ask', provider: 'openai', model: 'gpt-4')

    assert_nil registry.get(:ask_llm_errors_total)
  end

  # --- metadata labels ---------------------------------------------------

  def test_configured_metadata_keys_become_labels
    Ask::Observability.config.label_metadata = [:workspace_id]
    Ask::Observability::Metrics.reset! # label set is fixed at creation

    instrument('chat.ask', provider: 'openai', model: 'gpt-4') do
      # with_metadata merges into the event payload
      Ask::Instrumentation.with_metadata(workspace_id: 7) do
        instrument('chat.ask', provider: 'openai', model: 'gpt-4')
      end
    end

    assert_equal 1, calls(provider: 'openai', model: 'gpt-4', kind: 'chat', workspace_id: '7')
  end

  def test_missing_metadata_label_is_unknown
    Ask::Observability.config.label_metadata = [:workspace_id]
    Ask::Observability::Metrics.reset!

    instrument('chat.ask', provider: 'openai', model: 'gpt-4')

    assert_equal 1, calls(provider: 'openai', model: 'gpt-4', kind: 'chat', workspace_id: 'unknown')
  end

  # --- install semantics -------------------------------------------------

  def test_install_is_idempotent
    Ask::Observability.install # second call

    2.times { instrument('chat.ask', provider: 'openai', model: 'gpt-4') }

    assert_equal 2, calls(provider: 'openai', model: 'gpt-4', kind: 'chat')
  end

  def test_install_with_enabled_false_is_noop
    setup_observability
    Ask::Observability.config.enabled = false
    Ask::Observability.install

    instrument('chat.ask', provider: 'openai', model: 'gpt-4')

    assert_nil registry.get(:ask_llm_calls_total)
    refute_predicate Ask::Observability, :installed?
  end
end
