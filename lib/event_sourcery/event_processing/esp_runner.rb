module EventSourcery
  module EventProcessing
    # NOTE: databases should be disconnected before running this
    # EventSourcery.config.postgres.event_store_database.disconnect
    class ESPRunner
      def initialize(event_processors:,
                     event_source:,
                     max_seconds_for_processes_to_terminate: 30,
                     shutdown_requested: false,
                     after_fork: nil,
                     after_subprocess_termination: nil,
                     logger: EventSourcery.logger)
        @event_processors = event_processors
        @event_source = event_source
        @pids = {}
        @max_seconds_for_processes_to_terminate = max_seconds_for_processes_to_terminate
        @shutdown_requested = shutdown_requested
        @exit_status = true
        @after_fork = after_fork
        @after_subprocess_termination = after_subprocess_termination
        @logger = logger
      end

      # Start each Event Stream Processor in a new child process.
      def start!
        with_logging do
          start_processes
          listen_for_shutdown_signals
          while_waiting_for_shutdown do
            record_terminated_processes
          end
          terminate_remaining_processes
          until all_processes_terminated? || waited_long_enough?
            record_terminated_processes
          end
          kill_remaining_processes
          record_terminated_processes until all_processes_terminated?
        end
        exit_indicating_status_of_processes
      end

      def start_processor(event_processor)
        process = ESPProcess.new(
          event_processor: event_processor,
          event_source: @event_source,
          after_fork: @after_fork,
        )
        pid = Process.fork { process.start }
        @pids[pid] = event_processor
      end

      def shutdown
        @shutdown_requested = true
      end

      def shutdown_requested?
        @shutdown_requested
      end

      private

      attr_reader :logger

      def with_logging
        logger.info('ESPRunner: Forking processes')
        yield
        logger.info('ESPRunner: Processes shutdown')
      end

      def start_processes
        @event_processors.each(&method(:start_processor))
      end

      def listen_for_shutdown_signals
        %i(TERM INT).each do |signal|
          Signal.trap(signal) { shutdown }
        end
      end

      def while_waiting_for_shutdown
        loop do
          yield
          break if shutdown_requested?
          sleep(1)
        end
      end

      def terminate_remaining_processes
        send_signal_to_remaining_processes(:TERM)
      end

      def kill_remaining_processes
        send_signal_to_remaining_processes(:KILL)
      end

      def send_signal_to_remaining_processes(signal)
        return if all_processes_terminated?

        logger.info("ESPRunner: Sending #{signal} to [#{@pids.values.map(&:processor_name).join(', ')}]")
        Process.kill(signal, *@pids.keys)
      rescue Errno::ESRCH
        record_terminated_processes
        retry
      end

      def record_terminated_processes
        until all_processes_terminated? || (pid, status = Process.wait2(-1, Process::WNOHANG)).nil?
          event_processor = @pids.delete(pid)
          logger.info("ESPRunner: Process #{event_processor&.processor_name || pid} " \
                      "terminated with exit status: #{status.exitstatus.inspect}")
          next unless event_processor
          @exit_status &&= !!status.success?
          @after_subprocess_termination&.call(processor: event_processor, runner: self, exit_status: status.exitstatus)
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
