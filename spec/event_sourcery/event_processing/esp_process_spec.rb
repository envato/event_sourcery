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
  let(:error_handler) { double }

  describe '#start' do
    subject(:start) { esp_process.start }
    let(:error) { StandardError.new }
    let(:logger) { spy(Logger) }

    before do
      allow(EventSourcery.config.error_handler_class).to receive(:new)
        .with(processor_name: processor_name).and_return(error_handler)
      allow(EventSourcery).to receive(:logger).and_return(logger)
      allow(error_handler).to receive(:with_error_handling).and_yield
      allow(logger).to receive(:info)
      allow(Process).to receive(:setproctitle)

      allow(esp).to receive(:subscribe_to)

      start
    end


    it 'names process with ESP name' do
      expect(Process).to have_received(:setproctitle).with(processor_name)
    end

    it 'wraps event processing inside error handler' do
      expect(error_handler).to have_received(:with_error_handling)
    end

    it 'logs info when starting and stopping ESP' do
      expect(logger).to have_received(:info).with("Starting #{processor_name}")
    end

    it 'subscribes event processor to event store' do
      expect(esp).to have_received(:subscribe_to)
    end
  end
end
