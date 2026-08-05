# frozen_string_literal: true

module Ask
  module Observability
    # Rack endpoint rendering the registry in Prometheus text format.
    # Mounted by the railtie at Configuration#metrics_path; the collector
    # scrapes it and ships to OpenObserve/Grafana.
    class MetricsApp
      def call(_env)
        body = Prometheus::Client::Formats::Text.marshal(Ask::Observability.registry)
        [200,
         { 'Content-Type' => 'text/plain; version=0.0.4; charset=utf-8',
           'Content-Length' => body.bytesize.to_s },
         [body]]
      end
    end
  end
end
