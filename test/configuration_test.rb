# frozen_string_literal: true

require_relative 'test_helper'

class ConfigurationTest < Minitest::Test
  def setup
    @config = Ask::Observability::Configuration.new
  end

  def test_defaults
    assert @config.enabled
    assert_nil @config.service_name
    assert_equal 'http://localhost:4318/v1/traces', @config.otlp_endpoint
    assert @config.json_logging
    assert_equal '/metrics', @config.metrics_path
    assert_equal [], @config.label_metadata
  end

  def test_otlp_endpoint_reads_environment
    ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://collector:4318/v1/traces'
    config = Ask::Observability::Configuration.new

    assert_equal 'http://collector:4318/v1/traces', config.otlp_endpoint
  ensure
    ENV.delete('OTEL_EXPORTER_OTLP_ENDPOINT')
  end

  def test_metadata_label_keys_normalizes_to_symbols
    @config.label_metadata = %w[workspace_id org]

    assert_equal %i[workspace_id org], @config.metadata_label_keys
  end

  def test_metadata_label_keys_empty_by_default
    assert_equal [], @config.metadata_label_keys
  end
end
