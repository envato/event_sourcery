RSpec.describe EventSourcery::EventProcessing::ErrorHandlers::ConstantRetry do
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
    allow(error_handler).to receive(:sleep)
  end

  describe '#with_error_handling' do
    let(:cause) { double(to_s: 'OriginalError', backtrace: ['back', 'trace']) }
    let(:event) { double(uuid: SecureRandom.uuid) }
    let(:number_of_errors_to_raise) { 3 }
    subject(:with_error_handling) do
      @count = 0
      error_handler.with_error_handling do
        @count +=1
        raise error if @count <= number_of_errors_to_raise
      end
    end

    context 'when the raised error is StandardError' do
      before { with_error_handling }
      let(:error) { StandardError.new('Some error') }
      it 'logs the errors' do
        expect(logger).to have_received(:error).thrice
      end

      it 'calls on_event_processor_error with error and processor name' do
        expect(on_event_processor_error).to have_received(:call).thrice.with(error, processor_name)
      end

      it 'sleeps the process at default interval' do
        expect(error_handler).to have_received(:sleep).with(1).thrice
      end
    end

    context 'when the raised errors are EventProcessingError' do
      let(:error) { EventSourcery::EventProcessingError.new(event: event) }
      before do
        allow(error).to receive(:cause).and_return(cause)
        with_error_handling
      end

      it 'logs the original error' do
        expect(logger).to have_received(:error).thrice.with("Processor #{processor_name} died with OriginalError.\nback\ntrace")
      end

      it 'calls on_event_processor_error with error and processor name' do
        expect(on_event_processor_error).to have_received(:call).thrice.with(cause, processor_name)
      end

      it 'sleeps the process at default interval' do
        expect(error_handler).to have_received(:sleep).with(1).thrice
      end
    end
  end
end
