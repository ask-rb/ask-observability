# frozen_string_literal: true

module Ask
  module Observability
    # Rails Railtie that wires ask-observability into any Rails app:
    #
    #   * bootstraps OpenTelemetry + JSON logging,
    #   * installs the metrics subscriber,
    #   * mounts the /metrics endpoint (Configuration#metrics_path).
    #
    # Everything honors Configuration#enabled; a host app that wants none
    # of it sets `enabled = false` in an initializer.
    class Railtie < ::Rails::Railtie
      # JSON logging must be declared before rails_semantic_logger builds
      # the logger: its +:initialize_logger+ initializer (which replaces
      # Rails') runs in group :all and consumes the appenders config there
      # — anything added later lands on the default colored appender.
      initializer 'ask.observability.logging', group: :all, before: :initialize_logger do |_app|
        next if Ask::Observability.config.enabled == false

        Ask::Observability::Bootstrap.install_json_logging
      end

      initializer 'ask.observability' do |_app|
        next if Ask::Observability.config.enabled == false

        Ask::Observability::Bootstrap.install
        Ask::Observability.install
      end

      initializer 'ask.observability.metrics' do |app|
        path = Ask::Observability.config.metrics_path
        next if path.nil? || Ask::Observability.config.enabled == false

        app.routes.append do
          # MetricsApp is a Rack app (instance #call), so mount an instance.
          mount Ask::Observability::MetricsApp.new, at: path
        end
      end
    end
  end
end
