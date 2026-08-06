# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-08-06

### Added

- `Ask::Observability.counter` / `Ask::Observability.histogram` — reload-safe
  register-or-resolve accessors on the shared registry. App files that
  register metrics are re-evaluated by Zeitwerk during development reloads,
  which re-registered the same names against a registry that still held them
  and raised `AlreadyRegisteredError` (surfacing as a 500 in the host app);
  the accessors resolve the existing metric instead.

## [0.1.0] - 2026-08-06

### Added

- Subscriber turning `ask-instrumentation` events into Prometheus metrics:
  `ask_llm_calls_total`, `ask_llm_tokens_total` (input/output),
  `ask_llm_duration_seconds` histogram, `ask_llm_errors_total`.
- `Ask::Observability.install` (idempotent) and `uninstall` (test isolation).
- `Ask::Observability.registry` — process registry, injectable for tests.
- `Ask::Observability.with_context` — metadata into events AND Rails log tags.
- `Ask::Observability::Bootstrap` — OTel SDK + OTLP exporter wiring and JSON
  structured logging via `rails_semantic_logger`, gated by `OTEL_DISABLED`
  and the test environment.
- `Ask::Observability::MetricsApp` — Rack endpoint serving the registry in
  Prometheus text format.
- Rails railtie — auto bootstrap, auto install, `/metrics` mount; all
  honoring `Configuration#enabled`.
- `rails generate ask:observability:install` initializer generator.
- Configuration: `enabled`, `service_name`, `otlp_endpoint`, `json_logging`,
  `metrics_path`, `label_metadata` (with cardinality guardrails).
