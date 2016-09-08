RSpec.describe EventSourcery::Domain::AggregateRoot do
  def new_aggregate(id, &block)
    Class.new do
      include EventSourcery::Domain::AggregateRoot

      def initialize(id, event_sink)
        super
        @item_added_events = []
      end

      def apply_item_added(event)
        @item_added_events << event
      end
      attr_reader :item_added_events

      class_eval(&block) if block_given?
    end.new(id, event_sink)
  end

  subject(:aggregate) { new_aggregate('123') }
  let(:event_store) { EventSourcery::EventStore::Memory.new }
  let(:event_sink) { EventSourcery::EventStore::EventSink.new(event_store) }

  describe '#load_history' do
    context 'when the event type has a state change method' do
      it 'calls it' do
        events = [new_event(type: :item_added)]
        aggregate.load_history(events)
        expect(aggregate.item_added_events).to eq events
      end
    end

    context "when the event type doesn't have a state change method" do
      it 'raises an error' do
        events = [new_event(type: :item_removed)]
        expect {
          aggregate.load_history(events)
        }.to raise_error(EventSourcery::Domain::AggregateRoot::UnknownEventError)
      end
    end
  end

  describe '#apply_event' do
    subject(:aggregate) {
      new_aggregate('123') do
        def add_item(item)
          apply_event(EventSourcery::Event.new(type: :item_added, body: { id: item.id }))
        end
      end
    }

    before do
      aggregate.add_item(OpenStruct.new(id: 1234))
    end

    it 'updates state' do
      event = aggregate.item_added_events.first
      expect(event.type).to eq 'item_added'
      expect(event.body).to eq(id: 1234)
    end

    it 'saves the event' do
      emitted_event = event_store.get_next_from(0).first
      expect(emitted_event.id).to eq 1
      expect(emitted_event.type).to eq 'item_added'
      expect(emitted_event.body).to eq(id: 1234)
      expect(emitted_event.aggregate_id).to eq '123'
    end
  end
end
