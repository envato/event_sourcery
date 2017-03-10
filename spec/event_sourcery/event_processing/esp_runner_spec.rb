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
  let(:esp_process) { spy }

  before do
    allow(Signal).to receive(:trap)
    allow(EventSourcery::EventProcessing::ESPProcess)
      .to receive(:new)
      .and_return(esp_process)
  end

  describe 'start!' do
    subject(:start!) { esp_runner.start! }

    it 'starts ESP processes' do
      start!
      expect(EventSourcery::EventProcessing::ESPProcess)
        .to have_received(:new)
        .with(
          event_processor: esp,
          event_store: event_store,
          on_event_processor_error: custom_on_event_processor_error,
          stop_on_failure: stop_on_failure
        )
      expect(esp_process).to have_received(:start)
    end

    describe 'graceful shutdown' do
      %i(TERM INT).each do |signal|
        context "upon receiving a #{signal} signal" do
          before do
            allow(Signal).to receive(:trap).with(signal).and_yield
          end

          it 'it terminates its ESP processes' do
            start!
            expect(esp_process).to have_received(:terminate)
          end
        end
      end
    end
  end
end
