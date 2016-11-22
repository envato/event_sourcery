RSpec.describe EventSourcery::EventProcessing::ESPRunner do
  subject(:esp_runner) { described_class.new(event_processors: event_processors, event_store: event_store, stop_on_failure: stop_on_failure) }
  let(:event_store) { double(:event_store) }
  let(:event_processors) { [esp] }
  let(:stop_on_failure) { false }

  let(:esp) { double(:esp) }

  before do
    allow(esp_runner).to receive(:fork).and_yield
  end

  describe 'start!' do
    subject(:start!) { dispatcher.start! }

    before do
      allow(esp).to receive(:subscribe_to)
    end

    it 'traps SIGINT signal from parent process' do
      expect(Signal).to receive(:trap).with('SIGTERM')
      esp_runner.start!
    end

    it 'subscribes ESPs' do
      esp_runner.start!
      expect(esp).to have_received(:subscribe_to).with(event_store)
    end

    it 'retries on failure' do
      counter = 0
      allow(esp).to receive(:subscribe_to) do
        counter += 1
        raise StandardError if counter < 2
      end
      esp_runner.start!
      expect(esp).to have_received(:subscribe_to).twice
    end

    context 'when processors are expected to stop on failure' do
      let(:stop_on_failure) { true }

      it 'does not retry on failure' do
        allow(esp).to receive(:subscribe_to).and_raise(StandardError)
        esp_runner.start!
        expect(esp).to have_received(:subscribe_to).once
      end
    end
  end
end
