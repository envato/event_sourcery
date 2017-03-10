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
        @processes = []
      end

      def start!
        with_runner_logging do
          start_processors
          setup_shutdown_hooks
          wait_for_processors
        end
      end

      private

      def with_runner_logging
        EventSourcery.logger.info { 'Forking ESP processes' }
        yield
        EventSourcery.logger.info { 'ESP processes shutdown' }
      end

      def start_processors
        @event_processors.each(&method(:start_processor))
      end

      def start_processor(event_processor)
        process = ESPProcess.new(
          event_processor: event_processor,
          event_store: @event_store,
          on_event_processor_error: @on_event_processor_error,
          stop_on_failure: @stop_on_failure
        )
        process.start
        @processes << process
      end

      def setup_shutdown_hooks
        %i(TERM INT).each do |signal|
          Signal.trap(signal, &method(:terminate_processors))
        end
      end

      def terminate_processors
        @processes.each(&:terminate)
      end

      def wait_for_processors
        Process.waitall
      end
    end
  end
end
