# frozen_string_literal: true

require_relative 'test_helper'

# The registry accessors (Ask::Observability.counter/histogram) resolve an
# existing metric instead of raising AlreadyRegisteredError when app files
# re-evaluate during development code reloads.
class ReloadSafeMetricsTest < Minitest::Test
  include ObservabilityTestHelpers

  def setup
    setup_observability
  end

  def teardown
    teardown_observability
  end

  def test_counter_registers_and_increments
    counter = Ask::Observability.counter(:voice_turns_total, docstring: 'turns')
    counter.increment

    assert_equal 1, counter.get
    assert_kind_of Prometheus::Client::Counter,
                   Ask::Observability.registry.get(:voice_turns_total)
  end

  def test_counter_resolves_existing_metric_after_reload
    first = Ask::Observability.counter(:voice_turns_total, docstring: 'turns')
    first.increment

    # Re-registration is what happens when a reloaded app file re-runs —
    # it must resolve the existing metric, not raise.
    second = Ask::Observability.counter(:voice_turns_total, docstring: 'turns')
    second.increment

    assert_same first, second
    assert_equal 2, first.get
  end

  def test_histogram_resolves_existing_metric_after_reload
    first = Ask::Observability.histogram(:voice_turn_latency_seconds, docstring: 'latency', buckets: [1, 2])
    second = Ask::Observability.histogram(:voice_turn_latency_seconds, docstring: 'latency', buckets: [1, 2])

    assert_same first, second
  end
end
