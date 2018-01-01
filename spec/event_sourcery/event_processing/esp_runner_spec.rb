RSpec.describe EventSourcery::EventProcessing::ESPRunner do
  subject(:esp_runner) do
    described_class.new(
      event_processors: event_processors,
      event_source: event_source,
      max_seconds_for_processes_to_terminate: 0.01,
      shutdown_requested: true
    )
  end
  let(:event_source) { spy(:event_source) }
  let(:event_processors) { [esp] }
  let(:esp) { spy(:esp, processor_name: processor_name) }
  let(:processor_name) { 'processor_name' }
  let(:esp_process) { spy }
  let(:pid) { 363_298 }
  let(:success_status) { instance_double(Process::Status, success?: true) }
  let(:failure_status) { instance_double(Process::Status, success?: false) }

  before do
    allow(EventSourcery::EventProcessing::ESPProcess)
      .to receive(:new)
      .and_return(esp_process)
    allow(Process).to receive(:fork).and_yield.and_return(pid)
    allow(Process).to receive(:kill)
    allow(Process).to receive(:wait2).and_return(nil, [pid, success_status])
    allow(Process).to receive(:exit)
    allow(Signal).to receive(:trap)
    allow(esp_runner).to receive(:shutdown)
  end

  describe 'start!' do
    subject(:start!) { esp_runner.start! }

    it 'starts ESP processes' do
      start!
      expect(EventSourcery::EventProcessing::ESPProcess)
        .to have_received(:new)
        .with(
          event_processor: esp,
          event_source: event_source,
        )
      expect(esp_process).to have_received(:start)
    end

    describe 'graceful shutdown' do
      %i(TERM INT).each do |signal|
        context "upon receiving a #{signal} signal" do
          before do
            allow(Signal).to receive(:trap).with(signal).and_yield
          end

          it 'it starts to shutdown' do
            start!
            expect(esp_runner).to have_received(:shutdown)
          end
        end
      end

      it 'sends processes the TERM signal' do
        start!
        expect(Process).to have_received(:kill).with(:TERM, pid)
      end

      it "exits indicating success" do
        start!
        expect(Process).to have_received(:exit).with(true)
      end

      context 'given the processes failed before shutdown' do
        before do
          allow(Process).to receive(:wait2).and_return([pid, failure_status])
        end

        it "doesn't send processes the TERM, or KILL signal" do
          start!
          expect(Process).to_not have_received(:kill)
        end

        it "exits indicating failure" do
          start!
          expect(Process).to have_received(:exit).with(false)
        end
      end

      context 'given the process exits just before sending signal' do
        before do
          allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
          allow(Process).to receive(:wait2).and_return(nil, [pid, failure_status])
        end

        it "doesn't send the signal more than once" do
          start!
          expect(Process).to have_received(:kill).with(:TERM, pid).once
        end

        it "exits indicating failure" do
          start!
          expect(Process).to have_received(:exit).with(false)
        end
      end

      context 'given the process does not terminate until killed' do
        before do
          @stop_process = false
          allow(Process).to receive(:wait2) { [pid, failure_status] if @stop_process }
          allow(Process).to receive(:kill).with(:KILL, pid) { @stop_process = true}
        end

        it 'sends processes the KILL signal' do
          start!
          expect(Process).to have_received(:kill).with(:KILL, pid)
        end

        it "exits indicating failure" do
          start!
          expect(Process).to have_received(:exit).with(false)
        end
      end
    end
  end
end
