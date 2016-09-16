RSpec.describe EventSourcery::Command::AggregateRoot do
  def new_aggregate(id, &block)
    Class.new do
      include EventSourcery::Command::AggregateRoot

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

  let(:aggregate_uuid) { SecureRandom.uuid }
  subject(:aggregate) { new_aggregate(aggregate_uuid) }
  let(:event_store) { EventSourcery::EventStore::Postgres::Connection.new(pg_connection) }
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
        }.to raise_error(EventSourcery::Command::AggregateRoot::UnknownEventError)
      end
    end
  end

  describe '#apply_event' do
    subject(:aggregate) {
      new_aggregate(aggregate_uuid) do
        def add_item(item)
          apply_event(EventSourcery::Event.new(type: :item_added, body: { id: item.id }))
        end
      end
    }

    it 'updates state' do
      aggregate.add_item(OpenStruct.new(id: 1234))
      event = aggregate.item_added_events.first
      expect(event.type).to eq 'item_added'
      expect(event.body).to eq("id" => 1234)
    end

    it 'saves the event with an initial version' do
      aggregate.add_item(OpenStruct.new(id: 1234))
      emitted_event = event_store.get_next_from(0).first
      expect(emitted_event.id).to eq 1
      expect(emitted_event.type).to eq 'item_added'
      expect(emitted_event.body).to eq('id' => 1234)
      expect(emitted_event.aggregate_id).to eq aggregate_uuid
      expect(emitted_event.version).to eq 1
    end

    context 'processing multiple commands' do
      it 'gets assigned the next version (no concurrent command processing occurred)' do
        aggregate.add_item(OpenStruct.new(id: 1234))
        aggregate.add_item(OpenStruct.new(id: 1234))
        aggregate.add_item(OpenStruct.new(id: 1234))
        emitted_versions = event_store.get_next_from(0).map(&:version)
        expect(emitted_versions).to eq([1, 2, 3])
      end
    end

    context 'when a concurrency error occurs' do
      it 'is raised' do
        aggregate.load_history(event_store.get_events_for_aggregate_id(aggregate_uuid))
        # change version
        event_store.sink(EventSourcery::Event.new(type: :item_added, aggregate_id: aggregate_uuid))
        expect {
          aggregate.add_item(OpenStruct.new(id: 1234))
        }.to raise_error(EventSourcery::ConcurrencyError)
      end
    end
  end

  it 'is impossible to insert a duplicate version directly' do
    pg_connection[:events].insert(aggregate_id: aggregate_uuid,
                                  type: 'blah',
                                  body: Sequel.pg_json({}),
                                  version: 1)
    expect {
      pg_connection[:events].insert(aggregate_id: aggregate_uuid,
                                    type: 'blah',
                                    body: Sequel.pg_json({}),
                                    version: 1)
    }.to raise_error(Sequel::UniqueConstraintViolation)
  end
end
