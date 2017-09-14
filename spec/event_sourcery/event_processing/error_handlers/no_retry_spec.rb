RSpec.describe EventSourcery::EventProcessing::ErrorHandlers::NoRetry do
  subject(:error_handler) do
    described_class.new(
      processor_name: processor_name,
    )
  end
  let(:processor_name) { 'processor_name' }
  let(:on_event_processor_error) { spy }
  let(:logger) { spy(Logger) }

  before do
    allow(EventSourcery.config).to receive(:on_event_processor_error).and_return(on_event_processor_error)
    allow(EventSourcery).to receive(:logger).and_return(logger)
    allow(logger).to receive(:error)
    allow(Process).to receive(:exit)
  end

  describe '#with_error_handling' do
    let(:cause) { double(to_s: 'OriginalError', backtrace: ['back', 'trace']) }
    let(:event) { double(uuid: SecureRandom.uuid) }
    subject(:with_error_handling) do
      error_handler.with_error_handling do
        raise error
      end
    end

    before do
      allow(error).to receive(:cause).and_return(cause)
      with_error_handling
    end

    context 'when the raised error is StandardError' do
      let(:error) { StandardError.new('Some error') }
      it 'logs the errors' do
        expect(logger).to have_received(:error).once
      end

      it 'calls on_event_processor_error with error and processor name' do
        expect(on_event_processor_error).to have_received(:call).once
      end

      it 'calls Process.exit(false)' do
        expect(Process).to have_received(:exit).with(false)
      end
    end

    context 'when the raised errors are EventProcessingError' do
      let(:event_processor) { double :event_processor }
      let(:error) { EventSourcery::EventProcessingError.new(event: event, processor: event_processor) }

      it 'logs the original error' do
        expect(logger).to have_received(:error).once.with("Processor #{processor_name} died with OriginalError.\nback\ntrace")
      end

      it 'calls on_event_processor_error with error and processor name' do
        expect(on_event_processor_error).to have_received(:call).once.with(cause, processor_name)
      end

      it 'calls Process.exit(false)' do
        expect(Process).to have_received(:exit).with(false)
      end
    end
  end
end
