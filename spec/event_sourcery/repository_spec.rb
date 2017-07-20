RSpec.describe EventSourcery::Repository do
  let(:event_store) { EventSourcery::Memory::EventStore.new }
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
  let(:events) { [ItemAdded.new(aggregate_id: aggregate_id)] }

  describe '.load' do
    RSpec.shared_examples 'news up an aggregate and loads history' do
      let(:added_events) { event_store.get_events_for_aggregate_id(aggregate_id) }

      subject(:aggregate) do
        described_class.load(aggregate_class, uuid, event_source: event_store, event_sink: event_sink)
      end

      specify { expect(aggregate.item_added_events).to eq(added_events) }
      context 'when aggregate_id is a string' do
        include_examples 'news up an aggregate and loads history' do
          let(:uuid) { aggregate_id }
        end
      end

      context 'when aggregate_id is convertible to a string' do
        include_examples 'news up an aggregate and loads history' do
          let(:uuid) { double(to_str: aggregate_id) }
        end
      end
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
