# frozen_string_literal: true

# Unlike esp_runner_spec.rb, which stubs Process.fork/kill/wait2, these tests
# fork real child processes to exercise the process orchestration end to end.
RSpec.describe EventSourcery::EventProcessing::ESPRunner do
  subject(:esp_runner) do
    described_class.new(
      event_processors: [event_processor],
      event_source: spy(:event_source),
      # Prevent the forked children from running RSpec's at_exit hook (which
      # would otherwise try to report the suite's results from the child).
      after_fork: ->(_processor) { RSpec::Core::Runner.disable_autorun! },
      logger: instance_spy(Logger)
    )
  end

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  after do
    reader.close unless reader.closed?
    writer.close unless writer.closed?
  end

  # Reaps the (single) child forked by start_processor and returns its status.
  def wait_for_child
    _pid, status = Process.wait2
    status
  end

  describe '#start_processor' do
    context 'given a processor that completes successfully' do
      let(:event_processor) do
        writer = self.writer
        instance_double(EventSourcery::EventProcessing::EventStreamProcessor).tap do |processor|
          allow(processor).to receive(:processor_name).and_return('success_processor')
          allow(processor).to receive(:subscribe_to) do
            # Runs in the forked child: report the child PID, then return so
            # the child exits cleanly.
            writer.write(Process.pid.to_s)
            writer.close
          end
        end
      end

      it 'runs the event processor in a separate child process' do
        esp_runner.start_processor(event_processor)
        writer.close
        status = wait_for_child

        child_pid = reader.read.to_i
        expect(child_pid).to_not eq(Process.pid)
        expect(status).to be_success
      end
    end

    context 'given a processor that raises' do
      around do |example|
        original_handler = EventSourcery.config.error_handler_class
        original_logger = EventSourcery.config.logger
        EventSourcery.config.error_handler_class = EventSourcery::EventProcessing::ErrorHandlers::NoRetry
        # The child logs the unhandled exception at FATAL; keep it out of the
        # test output by discarding log output for this example.
        EventSourcery.config.logger = Logger.new(File::NULL)
        example.run
        EventSourcery.config.error_handler_class = original_handler
        EventSourcery.config.logger = original_logger
      end

      let(:event_processor) do
        instance_double(EventSourcery::EventProcessing::EventStreamProcessor).tap do |processor|
          allow(processor).to receive(:processor_name).and_return('failing_processor')
          allow(processor).to receive(:subscribe_to).and_raise(StandardError, 'boom')
        end
      end

      it 'exits the child process with a failure status' do
        esp_runner.start_processor(event_processor)
        status = wait_for_child

        expect(status).to_not be_success
      end
    end
  end
end
