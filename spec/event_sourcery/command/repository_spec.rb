RSpec.describe EventSourcery::Command::Repository do
  let(:event_store) { EventSourcery::EventStore::Memory.new }
  let(:event_sink) { EventSourcery::EventStore::EventSink.new(event_store) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate_class) {
    Class.new do
      include EventSourcery::Command::AggregateRoot

      apply ItemAdded do |event|
        @item_added_events ||= []
        @item_added_events << event
      end
      attr_reader :item_added_events
    end
  }
  let(:events) { [new_event(type: :item_added, aggregate_id: aggregate_id)] }

  before { events.inject(event_store, :sink) }

  describe '.load' do
    let(:added_events) { event_store.get_events_for_aggregate_id(aggregate_id) }

    it 'news up an aggregate and loads history' do
      aggregate = described_class.load(aggregate_class, double(to_str: aggregate_id),
        event_source: event_store, event_sink: event_sink)

      expect(aggregate.item_added_events).to eq(added_events)
    end
  end
end
