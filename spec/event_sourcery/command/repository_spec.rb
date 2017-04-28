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
    RSpec.shared_examples 'news up an aggregate and loads history' do
      let(:added_events) { event_store.get_events_for_aggregate_id(aggregate_id) }

      subject(:aggregate) do
        described_class.load(aggregate_class, uuid, event_source: event_store, event_sink: event_sink)
      end

      specify { expect(aggregate.item_added_events).to eq(added_events) }
    end

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
