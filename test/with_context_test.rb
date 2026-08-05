# frozen_string_literal: true

require_relative 'test_helper'

class WithContextTest < Minitest::Test
  include ObservabilityTestHelpers

  def setup
    setup_observability
  end

  def teardown
    teardown_observability
    remove_fake_rails if defined?(@_fake_rails)
  end

  # A minimal Rails stand-in: a logger that records tagged blocks.
  def stub_rails
    tagged_calls = []
    logger = Object.new
    logger.define_singleton_method(:tagged) do |**tags, &block|
      tagged_calls << tags
      block.call
    end
    @_fake_rails = Module.new
    @_fake_rails.define_singleton_method(:logger) { logger }
    Object.const_set(:Rails, @_fake_rails)
    @tagged_calls = tagged_calls
  end

  def remove_fake_rails
    Object.send(:remove_const, :Rails) if Object.const_get(:Rails) == @_fake_rails
  end

  def test_metadata_reaches_events_emitted_inside_block
    seen = []
    Ask::Instrumentation.subscribe('chat.ask') { |event| seen << event.payload }

    Ask::Observability.with_context(call_id: 'call_1', workspace_id: 4) do
      instrument('chat.ask', provider: 'openai', model: 'gpt-4')
    end

    assert_equal 'call_1', seen.last[:call_id]
    assert_equal 4, seen.last[:workspace_id]
    assert_equal 'openai', seen.last[:provider]
  end

  def test_metadata_becomes_metric_labels_when_configured
    Ask::Observability.config.label_metadata = [:workspace_id]
    Ask::Observability::Metrics.reset! # label set is fixed at creation
    Ask::Observability.install

    Ask::Observability.with_context(workspace_id: 9) do
      instrument('chat.ask', provider: 'openai', model: 'gpt-4')
    end

    metric = Ask::Observability.registry.get(:ask_llm_calls_total)

    assert_equal 1, metric.get(labels: { provider: 'openai', model: 'gpt-4', kind: 'chat', workspace_id: '9' })
  end

  def test_returns_block_value
    result = Ask::Observability.with_context({}) { :done }

    assert_equal :done, result
  end

  def test_tags_rails_logs_when_rails_is_present
    stub_rails

    Ask::Observability.with_context(call_id: 'abc') { nil }

    assert_equal [{ call_id: 'abc' }], @tagged_calls
  end

  def test_works_without_rails
    result = Ask::Observability.with_context(call_id: 'abc') { :ok }

    assert_equal :ok, result
  end

  private

  def instrument(name, payload)
    Ask::Instrumentation.instrument(name, payload)
  end
end
