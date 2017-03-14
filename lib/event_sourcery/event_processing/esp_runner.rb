module EventSourcery
  module EventProcessing
    # NOTE: the event store database should be disconnected before running this
    # EventSourcery.config.event_store_database.disconnect
    class ESPRunner
      def initialize(event_processors:,
                     event_store:,
                     on_event_processor_error: EventSourcery.config.on_event_processor_error,
                     stop_on_failure: false,
                     max_seconds_for_processes_to_terminate: 30,
                     shutdown_requested: false)
        @event_processors = event_processors
        @event_store = event_store
        @on_event_processor_error = on_event_processor_error
        @stop_on_failure = stop_on_failure
        @pids = []
        @max_seconds_for_processes_to_terminate = max_seconds_for_processes_to_terminate
        @shutdown_requested = shutdown_requested
      end

      def start!
        with_logging do
          start_processes
          listen_for_shutdown_signals
          wait_till_shutdown_requested
          record_terminated_processes
          terminate_remaining_processes
          until all_processes_terminated? || waited_long_enough?
            record_terminated_processes
          end
          kill_remaining_processes
        end
      end

      private

      def with_logging
        EventSourcery.logger.info { 'Forking ESP processes' }
        yield
        EventSourcery.logger.info { 'ESP processes shutdown' }
      end

      def start_processes
        @event_processors.each(&method(:start_processor))
      end

      def start_processor(event_processor)
        process = ESPProcess.new(
          event_processor: event_processor,
          event_store: @event_store,
          on_event_processor_error: @on_event_processor_error,
          stop_on_failure: @stop_on_failure
        )
        @pids << Process.fork { process.start }
      end

      def listen_for_shutdown_signals
        %i(TERM INT).each do |signal|
          Signal.trap(signal) { shutdown }
        end
      end

      def shutdown
        @shutdown_requested = true
      end

      def wait_till_shutdown_requested
        sleep(1) until @shutdown_requested
      end

      def terminate_remaining_processes
        send_signal_to_remaining_processes(:TERM)
      end

      def kill_remaining_processes
        send_signal_to_remaining_processes(:KILL)
      end

      def send_signal_to_remaining_processes(signal)
        Process.kill(signal, *@pids) unless all_processes_terminated?
      rescue Errno::ESRCH
        record_terminated_processes
        retry
      end

      def all_processes_terminated?
        @pids.empty?
      end

      def record_terminated_processes
        until (pid = Process.wait(-1, Process::WNOHANG)).nil?
          @pids.delete(pid)
        end
      end

      def waited_long_enough?
        @timeout ||= Time.now + @max_seconds_for_processes_to_terminate
        Time.now >= @timeout
      end
    end
  end
end
