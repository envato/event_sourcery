RSpec.describe EventSourcery::EventProcessing::ESPProcess do
  subject(:esp_process) do
    described_class.new(
      event_processor: esp,
      event_store: event_store,
      subscription_master: subscription_master,
    )
  end
  let(:esp) { spy(:esp, processor_name: processor_name) }
  let(:processor_name) { 'processor_name' }
  let(:event_store) { spy(:event_store) }
  let(:subscription_master) { spy(EventSourcery::EventStore::SignalHandlingSubscriptionMaster) }
  let(:error_handler) do
    instance_double(
      EventSourcery::EventProcessing::ESPProcessErrorHandler,
      handle: nil,
      retry?: retry_on_error,
    )
  end

  describe '#start' do
    subject(:start) { esp_process.start }
    let(:error) { StandardError.new }
    let(:logger) { spy(Logger) }

    before do
      allow(EventSourcery::EventProcessing::ESPProcessErrorHandler).to receive(:new).and_return(error_handler)
      allow(EventSourcery).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      allow(Process).to receive(:exit)
      allow(Process).to receive(:setproctitle)

      counter = 0
      allow(esp).to receive(:subscribe_to) do
        counter += 1
        raise error if counter < 4
      end

      start
    end

    context 'given the subscription raises an error' do
      context 'and error handler suggests retry on error' do
        let(:retry_on_error) { true }

        it 'names process with ESP name' do
          expect(Process).to have_received(:setproctitle).with(processor_name)
        end

        it 'restarts the subscription after each failure' do
          expect(esp).to have_received(:subscribe_to).exactly(4).times
        end

        it 'delegates error handling to error handler' do
          expect(error_handler).to have_received(:handle).thrice
        end

        it 'logs info when starting and stopping ESP' do
          expect(logger).to have_received(:info).with("Starting #{processor_name}").exactly(4).times
          expect(logger).to have_received(:info).with("Stopping #{processor_name}").once
        end
      end

      context 'and error handler suggests no retry on error' do
        let(:retry_on_error) { false }

        it 'names process with ESP name' do
          expect(Process).to have_received(:setproctitle).with(processor_name)
        end

        it 'delegates error handling to error handler' do
          expect(error_handler).to have_received(:handle).once
        end

        it 'aborts after the first failure' do
          expect(esp).to have_received(:subscribe_to).once
        end

        it 'logs info when starting and stopping ESP' do
          expect(logger).to have_received(:info).with("Starting #{processor_name}").once
          expect(logger).to have_received(:info).with("Stopping #{processor_name}").once
        end

        it 'stops the process' do
          expect(Process).to have_received(:exit).with(false)
        end
      end
    end
  end
end
