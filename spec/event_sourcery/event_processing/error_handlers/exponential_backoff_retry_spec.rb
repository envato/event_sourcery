RSpec.describe EventSourcery::EventProcessing::ErrorHandlers::ExponentialBackoffRetry do
  subject(:error_handler) do
    described_class.new(
      processor_name: processor_name,
    )
  end
  let(:processor_name) { 'processor_name' }
  let(:on_event_processor_error) { spy }
  let(:logger) { spy(Logger) }

  before do
    @sleep_intervals = []
    allow(EventSourcery.config).to receive(:on_event_processor_error).and_return(on_event_processor_error)
    allow(EventSourcery).to receive(:logger).and_return(logger)
    allow(logger).to receive(:error)
    allow(error_handler).to receive(:sleep) { |interval| @sleep_intervals << interval }
  end

  describe '#with_error_handling' do
    let(:original_error) { double(to_s: 'OriginalError', backtrace: ['back', 'trace']) }
    let(:event) { double(uuid: SecureRandom.uuid) }
    let(:number_of_errors_to_raise) { 3 }
    subject(:with_error_handling) do
      @count = 0
      error_handler.with_error_handling do
        @count +=1
        raise error if @count <= number_of_errors_to_raise
      end
    end
    before { with_error_handling }

    context 'when the raised error is StandardError' do
      let(:error) { StandardError.new('Some error') }
      it 'logs the errors' do
        expect(logger).to have_received(:error).thrice
      end

      it 'calls on_event_processor_error with error and processor name' do
        expect(on_event_processor_error).to have_received(:call).thrice.with(error, processor_name)
      end

      it 'sleeps the process at default interval' do
        expect(@sleep_intervals).to eq [1, 1, 1]
      end
    end

    context 'when the raised errors are EventProcessingError for the same event' do
      let(:error) { EventSourcery::EventProcessingError.new(event, original_error) }

      it 'logs the original error' do
        expect(logger).to have_received(:error).thrice.with("Processor #{processor_name} died with OriginalError.\\n back\\ntrace")
      end

      it 'calls on_event_processor_error with error and processor name' do
        expect(on_event_processor_error).to have_received(:call).thrice.with(original_error, processor_name)
      end

      it 'sleeps the process at exponential increasing intervals' do
        expect(@sleep_intervals).to eq [1, 2, 4]
      end

      context 'when lots of errors are raised for the same event' do
        let(:number_of_errors_to_raise) { 10 }

        it 'sleeps the process at exponential increasing intervals' do
          expect(@sleep_intervals).to eq [1, 2, 4, 8, 16, 32, 64, 64, 64, 64]
        end
      end
    end

    context 'when the raised errors are EventProcessingError for the different events' do
      let(:error_for_event) { EventSourcery::EventProcessingError.new(event, original_error) }
      let(:another_event) { double(uuid: SecureRandom.uuid) }
      let(:error_for_another_event) { EventSourcery::EventProcessingError.new(another_event, original_error) }
      subject(:with_error_handling) do
        @count = 0
        error_handler.with_error_handling do
          @count +=1
          raise error_for_event if @count <= 3
          raise error_for_another_event if @count <= 5
        end
      end

      it 'resets retry interval when event uuid changes' do
        expect(@sleep_intervals).to eq [1, 2, 4, 1, 2]
      end
    end
  end
end
