module EventSourcery
  module EventProcessing
    # NOTE: the event store database should be disconnected before running this
    # EventSourcery.config.event_store_database.disconnect
    class ESPRunner
      def initialize(event_processors:, event_store:)
        @event_processors = event_processors
        @event_store = event_store
        @pids = []
      end

      def start!
        EventSourcery.logger.info { "Forking ESP processes" }
        @event_processors.each do |event_processor|
          pid = fork do
            start_processor(event_processor)
          end
          pids << pid
        end
        Signal.trap("SIGINT") { kill_child_processes }
        Signal.trap("SIGTERM") do
          EventSourcery.logger.error { "DIE 2!!!!!!" }
          kill_child_processes
        end
        Process.waitall
      end

      private

      attr_reader :pids

      def start_processor(event_processor)
        EventSourcery.logger.info { "Starting #{event_processor.processor_name}" }
        event_processor.subscribe_to(@event_store)
      rescue => e
        backtrace = e.backtrace.join("\n")
        EventSourcery.logger.error { "Processor #{event_processor.processor_name} died with #{e.to_s}. #{backtrace}" }
        sleep 1
        retry
      end

      def kill_child_processes
        pids.each do |pid|
          Process.kill("SIGTERM", pid)
        end
      end
    end
  end
end
