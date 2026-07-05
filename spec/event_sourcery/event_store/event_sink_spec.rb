# frozen_string_literal: true

RSpec.describe EventSourcery::EventStore::EventSink do
  subject(:event_sink) { described_class.new(event_store) }
  let(:event_store) { instance_double(EventSourcery::Memory::EventStore, sink: nil) }
  let(:event) { ItemAdded.new }

  describe '#sink' do
    it 'delegates to the underlying event store' do
      event_sink.sink(event, expected_version: 1)
      expect(event_store).to have_received(:sink).with(event, expected_version: 1)
    end

    it 'returns the result from the underlying event store' do
      allow(event_store).to receive(:sink).and_return(true)
      expect(event_sink.sink(event)).to be true
    end
  end

  it 'does not expose the underlying event store publicly' do
    expect(event_sink).to_not respond_to(:event_store)
  end
end
