# frozen_string_literal: true

require_relative 'lib/ask/observability/version'

Gem::Specification.new do |spec|
  spec.name = 'ask-observability'
  spec.version = Ask::Observability::VERSION
  spec.authors = ['Kaka Ruto']
  spec.email = ['kaka@myrrlabs.com']

  spec.summary = 'Prometheus metrics, OpenTelemetry, and structured logging for the ask-rb ecosystem'
  spec.description = 'Turns ask-instrumentation events into Prometheus metrics ' \
                     '(calls, tokens, duration, errors), bootstraps OpenTelemetry ' \
                     'span export and JSON structured logging for Rails apps, and ' \
                     'serves a /metrics endpoint — the infra-observability twin of ' \
                     "ask-monitoring's in-app dashboard."
  spec.homepage = 'https://github.com/ask-rb/ask-observability'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'ask-instrumentation', '>= 0.1'
  spec.add_dependency 'prometheus-client', '>= 4.0'
end
