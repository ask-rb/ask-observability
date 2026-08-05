# frozen_string_literal: true

require_relative 'test_helper'

class GemspecTest < Minitest::Test
  def test_gemspec_is_valid
    spec = Gem::Specification.load(File.expand_path('../ask-observability.gemspec', __dir__))

    assert spec, 'Could not load gemspec'
    assert_kind_of Gem::Specification, spec
    assert spec.name.to_s.start_with?('ask-')
    assert_operator spec.version.to_s, :>, '0'
  end

  def test_gemspec_declares_expected_dependencies
    spec = Gem::Specification.load(File.expand_path('../ask-observability.gemspec', __dir__))
    deps = spec.dependencies.to_h { |d| [d.name, d.type] }

    assert_equal :runtime, deps['ask-instrumentation']
    assert_equal :runtime, deps['prometheus-client']
  end

  def test_gemspec_packages_lib_and_meta_files
    spec = Gem::Specification.load(File.expand_path('../ask-observability.gemspec', __dir__))

    assert_includes spec.files, 'lib/ask/observability.rb'
    assert_includes spec.files, 'lib/ask/observability/subscriber.rb'
    assert_includes spec.files, 'README.md'
    assert_includes spec.files, 'CHANGELOG.md'
  end
end
