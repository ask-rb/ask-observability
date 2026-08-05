# frozen_string_literal: true

require 'rails/generators'

module Ask
  module Observability
    # Writes a config initializer so the app can tune ask-observability
    # before the railtie runs (label metadata, service name, /metrics path).
    #
    #   rails generate ask:observability:install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def copy_initializer
        template 'initializer.rb.erb', 'config/initializers/ask_observability.rb'
      end

      def show_next_steps
        say 'ask-observability installed. Configure it in ' \
            'config/initializers/ask_observability.rb — the railtie ' \
            'bootstraps OpenTelemetry + JSON logs, mounts /metrics, and ' \
            'tracks ask_llm_* metrics automatically.'
      end
    end
  end
end
