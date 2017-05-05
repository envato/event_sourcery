RSpec.describe EventSourcery::Repository do
  let(:event_store) { EventSourcery::EventStore::Memory.new }
  let(:event_sink) { EventSourcery::EventStore::EventSink.new(event_store) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate_class) {
    Class.new do
      include EventSourcery::AggregateRoot

      apply ItemAdded do |event|
        @item_added_events ||= []
        @item_added_events << event
      end
      attr_reader :item_added_events
    end
  }
  let(:events) { [new_event(type: :item_added, aggregate_id: aggregate_id)] }

  describe '#load' do
    before do
      events.each do |event|
        event_store.sink(event)
      end
    end

    it 'news up an aggregate and loads history' do
      aggregate = described_class.load(aggregate_class, aggregate_id, event_source: event_store, event_sink: event_sink)
      expect(aggregate.item_added_events).to eq event_store.get_events_for_aggregate_id(aggregate_id)
    end
  end

  describe '#save' do
    let(:version) { 20 }
    let(:aggregate) { double(EventSourcery::AggregateRoot, changes: changes, id: aggregate_id, version: version, clear_changes: nil) }
    let(:event_sink) { double(EventSourcery::EventStore::EventSink, sink: nil) }
    let(:event_source) { double(EventSourcery::EventStore::EventSink, get_events_for_aggregate_id: nil) }
    subject(:repository) { EventSourcery::Repository.new(event_source: event_source, event_sink: event_sink) }

    context 'when there are no changes' do
      let(:changes) { [] }

      it 'does nothing' do
        repository.save(aggregate)
        expect(event_sink).to_not have_received(:sink)
      end
    end

    context 'with one change' do
      let(:changes) { [ItemAdded.new(body: { title: 'Space Jam' })] }

      it 'saves the new events with the expected version set to the aggregate version minus the number of new events' do
        repository.save(aggregate)
        expect(event_sink).to have_received(:sink).with(changes, expected_version: version - changes.count)
      end
    end

    context 'with multiple changes' do
      let(:changes) { [ItemAdded.new(body: { title: 'Space Jam' }), ItemRemoved.new(body: { title: 'Space Jam' })] }

      it 'saves the new events with the expected version set to the aggregate version' do
        repository.save(aggregate)
        expect(event_sink).to have_received(:sink).with(changes, expected_version: version - changes.count)
      end
    end
  end
end
