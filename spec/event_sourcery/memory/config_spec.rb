RSpec.describe EventSourcery::Memory::Config do
  subject(:config) { described_class.new }

  context 'when reading the event_store' do
    it 'returns a EventSourcery::Memory::EventStore' do
      expect(config.event_store).to be_instance_of(EventSourcery::Memory::EventStore)
    end

    it 'returns a EventSourcery::EventStore::EventSource' do
      expect(config.event_source).to be_instance_of(EventSourcery::EventStore::EventSource)
    end

    it 'returns a EventSourcery::EventStore::EventSink' do
      expect(config.event_sink).to be_instance_of(EventSourcery::EventStore::EventSink)
    end

    it 'returns a EventSourcery::Memory::Tracker' do
      expect(config.event_tracker).to be_instance_of(EventSourcery::Memory::Tracker)
    end

    context 'and an event_store is set' do
      let(:event_store) { double(:event_store) }
      before do
        config.event_store = event_store
      end

      it 'returns the event_store' do
        expect(config.event_store).to eq(event_store)
      end
    end

  end
end
