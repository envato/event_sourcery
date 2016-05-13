RSpec.describe EventSourcery::EventSource do
  let(:events) { [] }
  let(:event_sink_adapter) { EventSourcery::EventSinkAdapters::Memory.new(events) }
  let(:event_sink) { EventSourcery::EventSink.new(event_sink_adapter) }
  subject(:event_store) { described_class.new(adapter) }

  describe 'adapter delegations' do
    let(:adapter) { double }

    before do
      allow(adapter).to receive(:get_next_from).and_return([])
      allow(adapter).to receive(:sink)
    end

    it 'delegates #get_next_from to the adapter' do
      result = event_store.get_next_from(1)
      expect(adapter).to have_received(:get_next_from).with(1)
    end
  end

  describe '#fetch_in_batches' do
    let(:adapter) { EventSourcery::EventSourceAdapters::Memory.new(events) }
    let(:aggregate_id) { SecureRandom.uuid }

    before do
      (1..2001).each do |i|
        event_sink.sink(aggregate_id: aggregate_id,
                        type: 'item_added',
                        body: {})
      end
    end

    def events_by_range(*args)
      [].tap do |events|
        event_store.fetch_in_batches(*args) do |events_batch|
          events_batch.each do |event|
            events << event
          end
        end
      end
    end

    context "the range doesn't include the latest event ID" do
      it 'returns only the events in the range' do
        events = events_by_range(1, 20)
        expect(events.count).to eq 20
        expect(events.map(&:id)).to eq((1..20).to_a)
      end
    end

    context 'the range includes the latest event ID' do
      it 'returns all the events' do
        events = events_by_range(1, 2001)
        expect(events.count).to eq 2001
        expect(events.map(&:id)).to eq((1..2001).to_a)
      end
    end

    context 'the range exceeds the latest event ID' do
      it 'returns all the events' do
        events = events_by_range(1, 2050)
        expect(events.count).to eq 2001
        expect(events.map(&:id)).to eq((1..2001).to_a)
      end
    end

    context 'the range filters by event type' do
      it 'returns only events of the given type' do
        expect(events_by_range(1, 2001, event_types: ['user_signed_up']).count).to eq 0
        expect(events_by_range(1, 2001, event_types: ['item_added']).count).to eq 2001
      end
    end
  end
end
