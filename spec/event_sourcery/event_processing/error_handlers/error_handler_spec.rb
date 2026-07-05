# frozen_string_literal: true

RSpec.describe EventSourcery::EventProcessing::ErrorHandlers::ErrorHandler do
  let(:handler_class) do
    Class.new do
      include EventSourcery::EventProcessing::ErrorHandlers::ErrorHandler

      def initialize(processor_name:)
        @processor_name = processor_name
      end
    end
  end
  subject(:error_handler) { handler_class.new(processor_name: 'my_processor') }

  describe '#with_error_handling' do
    it 'raises NotImplementedError when the including class does not override it' do
      expect { error_handler.with_error_handling }
        .to raise_error(NotImplementedError, 'Please implement #with_error_handling method')
    end
  end

  describe '#report_error (private)' do
    let(:logger) { instance_spy(Logger) }
    let(:on_event_processor_error) { spy }

    before do
      allow(EventSourcery).to receive(:logger).and_return(logger)
      allow(EventSourcery.config).to receive(:on_event_processor_error).and_return(on_event_processor_error)
    end

    context 'given a standard error' do
      let(:error) { StandardError.new('boom') }

      before { allow(error).to receive(:backtrace).and_return(%w[line1 line2]) }

      it 'logs the error with the processor name and backtrace' do
        error_handler.send(:report_error, error)
        expect(logger).to have_received(:error)
          .with("Processor my_processor died with boom.\nline1\nline2")
      end

      it 'calls the configured error callback with the error and processor name' do
        error_handler.send(:report_error, error)
        expect(on_event_processor_error).to have_received(:call).with(error, 'my_processor')
      end
    end

    context 'given an EventProcessingError wrapping an underlying cause' do
      let(:cause) { StandardError.new('original') }
      let(:error) do
        EventSourcery::EventProcessingError.new(event: double(:event), processor: double(:processor))
      end

      before do
        allow(error).to receive(:cause).and_return(cause)
        allow(cause).to receive(:backtrace).and_return(%w[line1])
      end

      it 'unwraps and reports the underlying cause rather than the wrapper' do
        error_handler.send(:report_error, error)
        expect(on_event_processor_error).to have_received(:call).with(cause, 'my_processor')
      end
    end
  end
end
