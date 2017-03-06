module EventSourcery
  module EventProcessing
    # NOTE: the event store database should be disconnected before running this
    # EventSourcery.config.event_store_database.disconnect
    class ESPRunner
      def initialize(event_processors:,
                     event_store:,
                     on_event_processor_error: EventSourcery.config.on_event_processor_error,
                     stop_on_failure: false)
        @event_processors = event_processors
        @event_store = event_store
        @on_event_processor_error = on_event_processor_error
        @stop_on_failure = stop_on_failure
        @pids = []
      end

      def start!
        EventSourcery.logger.info { "Forking ESP processes" }
        @event_processors.each do |event_processor|
          pid = fork do
            Process.setproctitle(event_processor.class.name)
            start_processor(event_processor)
          end
          pids << pid
        end
        Signal.trap(:TERM) { kill_child_processes }
        Signal.trap(:INT) { kill_child_processes }
        Process.waitall
      end

      private

      attr_reader :pids

      def start_processor(event_processor)
        EventSourcery.logger.info { "Starting #{event_processor.processor_name}" }
        graceful_shutdown = GracefulShutdown.new
        event_processor.subscribe_to(@event_store, graceful_shutdown: graceful_shutdown)
        Signal.trap(:TERM) { graceful_shutdown.shutdown_when_safe }
        Signal.trap(:INT) { graceful_shutdown.shutdown_when_safe }
      rescue => e
        backtrace = e.backtrace.join("\n")
        EventSourcery.logger.error { "Processor #{event_processor.processor_name} died with #{e.to_s}. #{backtrace}" }
        @on_event_processor_error.call(e, event_processor.processor_name)
        unless @stop_on_failure
          sleep 1
          retry
        end
      end

      def kill_child_processes
        pids.each do |pid|
          Process.kill(:TERM, pid)
        end
      end
    end
  end
end
