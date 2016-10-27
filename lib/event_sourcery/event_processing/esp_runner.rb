module EventSourcery
  module EventProcessing
    # NOTE: the event store database should be disconnected before running this
    # EventSourcery.config.event_store_database.disconnect
    class ESPRunner
      def initialize(event_processors:, event_store:)
        @event_processors = event_processors
        @event_store = event_store
      end

      def start!
        EventSourcery.logger.info { "Forking ESP processes" }
        @event_processors.each do |event_processor|
          fork do
            Signal.trap("SIGINT") { exit }
            start_processor(event_processor)
          end
        end
        Process.waitall
      end

      private

      def start_processor(event_processor)
        EventSourcery.logger.info { "Starting #{event_processor.processor_name}" }
        event_processor.subscribe_to(@event_store)
      rescue => e
        backtrace = e.backtrace.join("\n")
        EventSourcery.logger.error { "Processor #{event_processor.processor_name} died with #{e.to_s}. #{backtrace}" }
        sleep 1
        retry
      end
    end
  end
end
