RSpec.describe EventSourcery::Command::AggregateRoot do
  def new_aggregate(id,
                    on_unknown_event: EventSourcery.config.on_unknown_event,
                    use_optimistic_concurrency: true,
                    &block)
    Class.new do
      include EventSourcery::Command::AggregateRoot

      def initialize(id,
                     event_sink,
                     on_unknown_event: -> {},
                     use_optimistic_concurrency: true)
        super
        @item_added_events = []
      end

      def apply_item_added(event)
        @item_added_events << event
      end
      attr_reader :item_added_events

      def apply_dummy(event)
      end

      class_eval(&block) if block_given?
    end.new(id,
            event_sink,
            on_unknown_event: on_unknown_event,
            use_optimistic_concurrency: use_optimistic_concurrency)
  end

  let(:aggregate_uuid) { SecureRandom.uuid }
  subject(:aggregate) { new_aggregate(aggregate_uuid) }
  let(:event_store) { EventSourcery::EventStore::Postgres::ConnectionWithOptimisticConcurrency.new(pg_connection) }
  let(:event_sink) { EventSourcery::EventStore::EventSink.new(event_store) }

  describe '#load_history' do
    subject(:load_history) { aggregate.load_history(events) }

    context 'when the event type has a state change method' do
      let(:events) { [new_event(type: :item_added)] }

      it 'calls it' do
        load_history
        expect(aggregate.item_added_events).to eq events
      end
    end

    context "when the aggregate doesn't have a state change method for the loaded event" do
      let(:events) { [new_event(type: :item_removed)] }

      context 'using the default on_unknown_event' do
        it 'raises an error' do
          expect { load_history }
            .to raise_error(EventSourcery::Command::AggregateRoot::UnknownEventError)
        end
      end

      context 'using a custom on_unknown_event' do
        let(:custom_on_unknown_event) { spy }
        let(:aggregate) { new_aggregate(aggregate_uuid, on_unknown_event: custom_on_unknown_event) }

        it 'yields the event and aggregate to the on_unknown_event block' do
          load_history
          expect(custom_on_unknown_event)
            .to have_received(:call)
            .with(events.first, kind_of(EventSourcery::Command::AggregateRoot))
        end
      end
    end
  end

  describe '#apply_event' do
    before do
      # add a dummy event so that event.id != event.version
      event_store.sink(new_event(id: 1, type: :dummy, version: 1, aggregate_id: SecureRandom.uuid))
    end

    subject(:aggregate) {
      new_aggregate(aggregate_uuid) do
        def add_item(item)
          apply_event(EventSourcery::Event.new(type: :item_added, body: { id: item.id }))
        end
      end
    }

    context 'when optimistic concurrency is turned off' do
      subject(:aggregate) {
        new_aggregate(aggregate_uuid, use_optimistic_concurrency: false) do
          def add_item(item)
            apply_event(EventSourcery::Event.new(type: :item_added, body: { id: item.id }))
          end
        end
      }

      it "doesn't set version" do
        aggregate.add_item(OpenStruct.new(id: 1234))
        event = aggregate.item_added_events.first
        expect(event.type).to eq 'item_added'
        expect(event.body).to eq("id" => 1234)
        expect(event.version).to eq(nil)
      end
    end

    it 'updates state' do
      aggregate.add_item(OpenStruct.new(id: 1234))
      event = aggregate.item_added_events.first
      expect(event.type).to eq 'item_added'
      expect(event.body).to eq("id" => 1234)
    end

    it 'saves the event with an initial version' do
      aggregate.add_item(OpenStruct.new(id: 1234))
      emitted_event = event_store.get_next_from(0).last
      expect(emitted_event.id).to eq 2
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
        emitted_versions = event_store.get_events_for_aggregate_id(aggregate_uuid).map(&:version)
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

    context 'given an event hash' do
      subject(:aggregate) do
        new_aggregate(aggregate_uuid, use_optimistic_concurrency: false) do
          def add_item(item)
            apply_event(type: :item_added, body: { id: item.id })
          end
        end
      end

      it 'updates state' do
        aggregate.add_item(OpenStruct.new(id: 1234))

        event = aggregate.item_added_events.first
        expect(event.type).to eq 'item_added'
        expect(event.body).to eq('id' => 1234)
      end

      it 'saves the event with an initial version' do
        aggregate.add_item(OpenStruct.new(id: 1234))

        emitted_event = event_store.get_next_from(0).last
        expect(emitted_event.id).to eq 2
        expect(emitted_event.type).to eq 'item_added'
        expect(emitted_event.body).to eq('id' => 1234)
        expect(emitted_event.aggregate_id).to eq aggregate_uuid
        expect(emitted_event.version).to eq 1
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
