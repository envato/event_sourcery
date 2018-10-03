RSpec.describe EventSourcery::EventProcessing::ESPProcess do
  subject(:esp_process) do
    described_class.new(
      event_processor: esp,
      event_source: event_source,
      subscription_master: subscription_master,
      after_fork: after_fork,
    )
  end
  let(:esp) { spy(:esp, processor_name: processor_name, class: esp_class) }
  let(:esp_class) { double(name: 'SomeApp::Reactors::SomeReactor') }
  let(:processor_name) { 'processor_name' }
  let(:event_source) { spy(:event_source) }
  let(:subscription_master) { spy(EventSourcery::EventStore::SignalHandlingSubscriptionMaster) }
  let(:error_handler) { double }
  let(:after_fork) { nil }
  let(:on_event_processor_error) { spy }

  describe '#start' do
    subject(:start) { esp_process.start }
    let(:logger) { spy(Logger) }

    before do
      allow(EventSourcery.config.error_handler_class).to receive(:new)
        .with(processor_name: processor_name).and_return(error_handler)
      allow(EventSourcery).to receive(:logger).and_return(logger)
      allow(EventSourcery.config).to receive(:on_event_processor_error).and_return(on_event_processor_error)
    end

    context 'when no error is raised' do
      before do
        allow(error_handler).to receive(:with_error_handling).and_yield
        allow(logger).to receive(:info)
        allow(Process).to receive(:setproctitle)

        allow(esp).to receive(:subscribe_to)
      end

      it 'names process with ESP name' do
        start
        expect(Process).to have_received(:setproctitle).with('SomeApp::Reactors::SomeReactor')
      end

      it 'wraps event processing inside error handler' do
        start
        expect(error_handler).to have_received(:with_error_handling)
      end

      it 'logs info when starting ESP' do
        start
        expect(logger).to have_received(:info).with("Starting #{processor_name}")
      end

      it 'subscribes event processor to event store' do
        start
        expect(esp).to have_received(:subscribe_to)
      end

      it 'logs info when stopping ESP' do
        start
        expect(logger).to have_received(:info).with("Stopping #{processor_name}")
      end

      context 'when after_fork is omitted' do
        it 'calls the default after_fork with the processor' do
          expect(EventSourcery::EventProcessing::ESPProcess::DEFAULT_AFTER_FORK).to receive(:call).with(esp)
          described_class.new(
            event_processor: esp,
            event_source: event_source,
            subscription_master: subscription_master,
          ).start
        end
      end

      context 'with after_fork set' do
        let(:after_fork) { spy(:after_fork) }

        it 'calls after_fork with the processor' do
          start
          expect(after_fork).to have_received(:call).with(esp)
        end
      end
    end

    context 'when the raised error is Exception' do
      let(:error) { Exception.new('Non-standard error') }

      before do
        allow(error_handler).to receive(:with_error_handling).and_raise(error)
        allow(logger).to receive(:error).with(error)
      end

      it 'logs and re-raises the error' do
        expect { start }.to raise_error(error)
        expect(logger).to have_received(:fatal).with(error)
        expect(on_event_processor_error).to have_received(:call).with(error, processor_name)
      end
    end
  end
end
