# frozen_string_literal: true

require_relative 'test_helper'

class MetricsAppTest < Minitest::Test
  include ObservabilityTestHelpers

  def setup
    setup_observability
  end

  def teardown
    teardown_observability
  end

  def test_serves_prometheus_text_format
    Ask::Observability.install
    instrument('chat.ask', provider: 'openai', model: 'gpt-4')

    status, headers, body = Ask::Observability::MetricsApp.new.call({})
    text = body.join

    assert_equal 200, status
    assert_includes headers['Content-Type'], 'text/plain'
    assert_includes text, 'ask_llm_calls_total'
    assert_includes text, 'ask_llm_calls_total{provider="openai",model="gpt-4",kind="chat"} 1'
  end

  def test_serves_metrics_from_the_injected_registry
    Ask::Observability.registry = Prometheus::Client::Registry.new
    Ask::Observability::Metrics.reset!
    registry = Ask::Observability.registry
    registry.counter(:app_custom_total, docstring: 'app metric', labels: [:x])
            .increment(labels: { x: 'y' })

    _, _, body = Ask::Observability::MetricsApp.new.call({})

    assert_includes body.join, 'app_custom_total{x="y"} 1'
  end

  def test_empty_registry_still_renders
    status, _headers, body = Ask::Observability::MetricsApp.new.call({})

    assert_equal 200, status
    assert_equal '', body.join
  end

  private

  def instrument(name, payload)
    Ask::Instrumentation.instrument(name, payload)
  end
end
