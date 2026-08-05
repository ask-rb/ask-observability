# ask-observability

Prometheus metrics, OpenTelemetry bootstrap, and structured logging for the
ask-rb ecosystem.

The ask-rb observability story composes four small gems:

| Gem | Job |
|---|---|
| `ask-instrumentation` | emits an event for every LLM operation |
| `ask-opentelemetry` | events → OpenTelemetry **spans** |
| **ask-observability** | events → Prometheus **metrics**, plus the OTel + logging bootstrap and `/metrics` |
| `ask-monitoring` | events → in-app **dashboard** + alerts |

`ask-observability` is the infra-observability twin of `ask-monitoring`:
where the dashboard answers "what is the app spending?" inside the product,
these metrics answer "is the service healthy?" in Prometheus/OpenObserve/
Grafana, with alerting.

## Installation

```ruby
gem "ask-observability"
gem "ask-instrumentation"
```

## Quick start (plain Ruby)

```ruby
require "ask/observability"

Ask::Observability.install
```

Every `Ask::Instrumentation` event now maintains:

```
ask_llm_calls_total{provider,model,kind}
ask_llm_tokens_total{provider,model,kind,direction}
ask_llm_duration_seconds{provider,model,kind}
ask_llm_errors_total{provider,kind}
```

Read the registry from anywhere:

```ruby
Ask::Observability.registry
```

## Quick start (Rails)

The railtie auto-installs: OpenTelemetry spans export to the OTLP collector,
logs become JSON on stdout, `/metrics` is mounted, and the subscriber runs.
Run the generator for a config file to tune it:

```sh
rails generate ask:observability:install
```

```ruby
Ask::Observability.configure do |config|
  config.service_name = "my-app"
  config.label_metadata = [:workspace_id] # low-cardinality ONLY
end
```

### Configuration

| Option | Default | Purpose |
|---|---|---|
| `enabled` | `true` | master switch (set `false` in tests/CI) |
| `service_name` | Rails app name / `"ask-app"` | `service.name` for spans and logs |
| `otlp_endpoint` | `ENV["OTEL_EXPORTER_OTLP_ENDPOINT"]` or `http://localhost:4318/v1/traces` | OTLP/HTTP span export |
| `json_logging` | `true` | JSON logs on stdout via `rails_semantic_logger` (skipped if the app configured its own appenders) |
| `metrics_path` | `"/metrics"` | where `/metrics` is mounted (`nil` disables the mount) |
| `label_metadata` | `[]` | `Ask::Instrumentation.with_metadata` keys exposed as metric labels |

> **Cardinality warning:** every distinct label value creates a new time
> series. Only configure low-cardinality metadata keys (`workspace_id`,
> `org`, `tenant`). Never put request ids or call ids in `label_metadata`.
> Configure before the first event — prometheus-client fixes a metric's
> label keys at creation.

### Correlating a unit of work everywhere

`with_context` pushes the same metadata into instrumentation events (and
thus spans + metrics) *and* into Rails log lines as tags:

```ruby
Ask::Observability.with_context(call_id: "abc", workspace_id: 4) do
  # events carry call_id/workspace_id; Rails logs are tagged with them
end
```

## Serving metrics yourself

If the mounted path conflicts with your app, point `metrics_path` elsewhere
or `nil` and mount the Rack app yourself:

```ruby
# config/routes.rb
mount Ask::Observability::MetricsApp, at: "/ops/metrics"
```

## Disabling

Set `config.enabled = false` — the subscriber, the OTel bootstrap, and the
/metrics mount all no-op. For tests, `OTEL_DISABLED=true` (or the test
environment) additionally skips the OpenTelemetry SDK configuration.

## Development

```sh
bin/setup          # bundle install + git hooks
bundle exec rake test
```

## License

MIT
