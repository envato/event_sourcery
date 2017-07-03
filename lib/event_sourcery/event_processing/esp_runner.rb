module EventSourcery
  module EventProcessing
    # NOTE: databases should be disconnected before running this
    # EventSourcery.config.postgres.event_store_database.disconnect
    class ESPRunner
      def initialize(event_processors:,
                     event_source:,
                     max_seconds_for_processes_to_terminate: 30,
                     shutdown_requested: false)
        @event_processors = event_processors
        @event_source = event_source
        @pids = []
        @max_seconds_for_processes_to_terminate = max_seconds_for_processes_to_terminate
        @shutdown_requested = shutdown_requested
        @exit_status = true
      end

      # Start each Event Stream Processor in a new child process.
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
          record_terminated_processes until all_processes_terminated?
        end
        exit_indicating_status_of_processes
      end

      private

      def with_logging
        EventSourcery.logger.info { 'Forking ESP processes' }
        yield
        EventSourcery.logger.info { 'ESP processes shutdown' }
      end

      def start_processes
        @event_processors.each(&method(:start_process))
      end

      def start_process(event_processor)
        process = ESPProcess.new(
          event_processor: event_processor,
          event_source: @event_source
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

      def record_terminated_processes
        until all_processes_terminated? ||
              ((pid, status) = Process.wait2(-1, Process::WNOHANG)).nil?
          @pids.delete(pid)
          @exit_status &&= status.success?
        end
      end

      def all_processes_terminated?
        @pids.empty?
      end

      def waited_long_enough?
        @timeout ||= Time.now + @max_seconds_for_processes_to_terminate
        Time.now >= @timeout
      end

      def exit_indicating_status_of_processes
        Process.exit(@exit_status)
      end
    end
  end
end
