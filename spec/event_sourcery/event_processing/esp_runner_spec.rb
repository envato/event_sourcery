RSpec.describe EventSourcery::EventProcessing::ESPRunner do
  subject(:esp_runner) do
    described_class.new(
      event_processors: event_processors,
      event_store: event_store,
      on_event_processor_error: custom_on_event_processor_error,
      stop_on_failure: stop_on_failure
    )
  end
  let(:event_store) { spy(:event_store) }
  let(:event_processors) { [esp] }
  let(:stop_on_failure) { false }
  let(:custom_on_event_processor_error) { spy }
  let(:esp) { spy(:esp, processor_name: processor_name) }
  let(:processor_name) { "processor_name" }

  before do
    allow(esp_runner).to receive(:fork).and_yield
    allow(Signal).to receive(:trap)
  end

  describe 'start!' do
    subject(:start!) { esp_runner.start! }

    it 'traps TERM signal' do
      start!
      expect(Signal).to have_received(:trap).with(:TERM).at_least(:once)
    end

    it 'subscribes ESPs' do
      start!
      expect(esp).to have_received(:subscribe_to)
        .with(event_store,
              subscription_master: kind_of(EventSourcery::EventStore::SubscriptionMaster))
    end

    context 'on exception' do
      let(:error) { StandardError.new }
      let(:logger) { spy(EventSourcery.logger) }

      before do
        allow(esp).to receive(:subscribe_to).and_raise(error)
        allow(EventSourcery.logger).to receive(:error).and_return(logger)
      end

      context 'retry enabled' do
        before do
          counter = 0
          allow(esp).to receive(:subscribe_to) do
            counter += 1
            raise error if counter < 2
          end
        end

        it 'retries on failure' do
          start!
          expect(esp).to have_received(:subscribe_to).twice
        end
      end

      context 'retry disabled' do
        let(:stop_on_failure) { true }

        it 'does not retry on failure' do
          start!
          expect(esp).to have_received(:subscribe_to).once
        end

        it 'calls on_event_processor_error with exception and processor name' do
          start!
          expect(custom_on_event_processor_error).to have_received(:call).with(error, processor_name)
        end

        it 'logs error' do
          start!
          expect(EventSourcery.logger).to have_received(:error)
        end
      end
    end
  end
end
