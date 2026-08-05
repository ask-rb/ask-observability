# frozen_string_literal: true

require_relative 'test_helper'

class MetricsTest < Minitest::Test
  include ObservabilityTestHelpers

  def setup
    setup_observability
  end

  def teardown
    teardown_observability
  end

  def metrics
    Ask::Observability.metrics
  end

  def test_defines_calls_total_with_kind_labels
    metric = metrics.calls_total

    assert_equal :ask_llm_calls_total, metric.name
    assert_equal %i[provider model kind], metric.instance_variable_get(:@labels)
  end

  def test_defines_tokens_total_with_direction
    metric = metrics.tokens_total

    assert_equal :ask_llm_tokens_total, metric.name
    assert_equal %i[provider model kind direction], metric.instance_variable_get(:@labels)
  end

  def test_defines_duration_histogram
    metric = metrics.duration_seconds

    assert_equal :ask_llm_duration_seconds, metric.name
    assert_equal %i[provider model kind], metric.instance_variable_get(:@labels)
  end

  def test_defines_errors_total
    metric = metrics.errors_total

    assert_equal :ask_llm_errors_total, metric.name
    assert_equal %i[provider kind], metric.instance_variable_get(:@labels)
  end

  def test_metadata_label_keys_join_every_metric
    Ask::Observability.config.label_metadata = [:workspace_id]
    metrics = Ask::Observability.metrics

    assert_equal %i[provider model kind workspace_id], metrics.calls_total.instance_variable_get(:@labels)
    assert_equal %i[provider kind workspace_id], metrics.errors_total.instance_variable_get(:@labels)
  end

  def test_memoized_per_registry
    first = Ask::Observability.metrics

    assert_same first, Ask::Observability.metrics

    Ask::Observability.registry = Prometheus::Client::Registry.new
    Ask::Observability::Metrics.reset!
    second = Ask::Observability.metrics

    refute_same first, second
  end
end
