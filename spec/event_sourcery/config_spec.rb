RSpec.describe EventSourcery::Config do
  subject(:config) { described_class.new }

  describe '#on_event_processor_critical_error' do
    subject(:on_event_processor_critical_error) { config.on_event_processor_critical_error }

    it 'has a default block set' do
      expect(on_event_processor_critical_error).to_not be_nil
      expect { on_event_processor_critical_error.call(nil, nil) }.to_not raise_error
    end

    it 'can set a block' do
      block = Object.new
      config.on_event_processor_critical_error = block
      expect(on_event_processor_critical_error).to be(block)
    end
  end
end

