RSpec.describe EventSourcery::EventProcessing::ESPProcessErrorHandler do
  subject(:error_handler) do
    described_class.new(
      processor_name: processor_name,
      retry_strategy: retry_strategy,
      on_event_processor_error: on_event_processor_error
    )
  end
  let(:processor_name) { 'processor_name' }
  let(:on_event_processor_error) { spy }

  describe '#retry?' do
    subject(:retry) { error_handler.retry? }
    context 'when retry strategy is "never"' do
      let(:retry_strategy) { :never }
      it { is_expected.to eq false }
    end

    context 'when retry strategy is "constant"' do
      let(:retry_strategy) { :constant }
      it { is_expected.to eq true }
    end

    context 'when retry strategy is "exponential"' do
      let(:retry_strategy) { :exponential }
      it { is_expected.to eq true }
    end
  end

  describe '#handle' do
    subject(:handle) { error_handler.handle(error) }
    let(:logger) { spy(Logger) }
    let(:retry_strategy) { :never }
    let(:error) { double(to_s: 'general error', backtrace: []) }

    before do
      allow(EventSourcery).to receive(:logger).and_return(logger)
      allow(logger).to receive(:error).and_yield
      allow(error_handler).to receive(:sleep)
    end

    describe 'logs error and triggers callback' do
      context 'and it is a general error' do
        it 'logs the error' do
          handle
          expect(logger).to have_received(:error)
        end

        it 'calls on_event_processor_error with error and processor name' do
          handle
          expect(on_event_processor_error)
            .to have_received(:call)
            .with(error, processor_name)
        end
      end

      context 'and it is a EventProcessingError' do
        let(:original_error) { double(to_s: 'general error', backtrace: []) }
        let(:error) { EventSourcery::EventProcessingError.new(double, original_error) }

        it 'logs the original error' do
          handle
          expect(logger).to have_received(:error)
        end

        it 'calls on_event_processor_error with error and processor name' do
          handle
          expect(on_event_processor_error)
            .to have_received(:call)
            .with(original_error, processor_name)
        end
      end
    end

    describe 'sleeps and updates retry interval' do
      context 'when retry strategy is "never"' do
        it 'does not sleep the process' do
          handle
          expect(error_handler).not_to have_received(:sleep)
        end
      end

      context 'when retry strategy is "constant"' do
        let(:retry_strategy) { :constant }

        context 'and general error' do
          it 'always sleeps for default interval' do
            error_handler.handle(error)
            error_handler.handle(error)
            expect(error_handler).to have_received(:sleep).with(1).twice
          end
        end

        context 'and EventProcessingError when processing the same event' do
          let(:original_error) { double(to_s: 'general error', backtrace: []) }
          let(:event) { double(uuid: SecureRandom.uuid) }
          let(:error) { EventSourcery::EventProcessingError.new(event, original_error) }

          it 'always sleeps for default interval' do
            error_handler.handle(error)
            error_handler.handle(error)
            error_handler.handle(error)
            expect(error_handler).to have_received(:sleep).with(1).thrice
          end
        end
      end

      context 'when retry strategy is "exponential"' do
        let(:retry_strategy) { :exponential }

        context 'and general error' do
          it 'always sleeps for default interval' do
            error_handler.handle(error)
            error_handler.handle(error)
            expect(error_handler).to have_received(:sleep).with(1).twice
          end
        end

        context 'and EventProcessingError when processing the same event' do
          let(:original_error) { double(to_s: 'general error', backtrace: []) }
          let(:event) { double(uuid: SecureRandom.uuid) }
          let(:error) { EventSourcery::EventProcessingError.new(event, original_error) }

          it 'always sleeps for default interval' do
            error_handler.handle(error)
            error_handler.handle(error)
            error_handler.handle(error)
            expect(error_handler).to have_received(:sleep).with(1).once
            expect(error_handler).to have_received(:sleep).with(2).once
            expect(error_handler).to have_received(:sleep).with(4).once
          end
        end
      end
    end
  end
end
