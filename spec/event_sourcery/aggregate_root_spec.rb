RSpec.describe EventSourcery::AggregateRoot do
  def new_aggregate(id,
                    on_unknown_event: EventSourcery.config.on_unknown_event,
                    &block)
    Class.new do
      include EventSourcery::AggregateRoot

      def initialize(id,
                     events,
                     on_unknown_event: -> {})
        @item_added_events = []
        @item_removed_events = []
        @added_and_removed_events = []
        super
      end

      apply ItemAdded do |event|
        @item_added_events << event
      end

      apply(ItemRemoved) do |event|
        @item_removed_events << event
      end

      apply ItemAdded, ItemRemoved do |event|
        @added_and_removed_events << event
      end

      attr_reader :item_added_events,
                  :item_removed_events,
                  :added_and_removed_events

      class_eval(&block) if block_given?
    end.new(id,
            events,
            on_unknown_event: on_unknown_event)
  end

  let(:aggregate_uuid) { SecureRandom.uuid }
  subject(:aggregate) { new_aggregate(aggregate_uuid) }

  context 'with no initial events' do
    let(:events) { [] }

    it 'initialises at version 0' do
      expect(aggregate.version).to eq 0
    end
  end

  context 'with initial events' do
    let(:events) { [ItemAdded.new(id: 1), ItemRemoved.new(id: 2)] }

    it 'calls registered handlers' do
      expect(aggregate.item_added_events).to eq [events.first]
      expect(aggregate.item_removed_events).to eq [events.last]
      expect(aggregate.added_and_removed_events).to eq events
    end

    it "updates it's version" do
      expect(aggregate.version).to eq events.count
    end
  end

  context "when the aggregate doesn't have a state change method for an event" do
    let(:events) { [TermsAccepted.new(id: 1)] }

    context 'using the default on_unknown_event' do
      it 'raises an error' do
        expect { aggregate }
          .to raise_error(EventSourcery::AggregateRoot::UnknownEventError)
      end
    end

    context 'using a custom on_unknown_event' do
      let(:custom_on_unknown_event) { spy }
      let(:aggregate) { new_aggregate(aggregate_uuid, on_unknown_event: custom_on_unknown_event) }

      it 'yields the event and aggregate to the on_unknown_event block' do
        aggregate
        expect(custom_on_unknown_event)
          .to have_received(:call)
          .with(events.first, kind_of(EventSourcery::AggregateRoot))
      end
    end
  end

  context 'when state changes' do
    let(:events) { [] }

    subject(:aggregate) {
      new_aggregate(aggregate_uuid) do
        def add_item(item)
          apply_event ItemAdded, body: { id: item.id }
        end
      end
    }

    before do
      aggregate.add_item(OpenStruct.new(id: 1234))
    end

    it 'updates state by calling the handler' do
      event = aggregate.item_added_events.first
      expect(event.type).to eq 'item_added'
      expect(event.body).to eq("id" => 1234)
    end

    it "increments it's version" do
      expect(aggregate.version).to eq 1
    end

    it 'exposes the new event in changes' do
      emitted_event = aggregate.changes.first
      expect(emitted_event.type).to eq 'item_added'
      expect(emitted_event.body).to eq('id' => 1234)
      expect(emitted_event.aggregate_id).to eq aggregate_uuid
    end

    context 'when changes are cleared' do
      it 'has no changes' do
        aggregate.clear_changes!
        expect(aggregate.changes).to eq []
      end

      it "maintains it's version" do
        aggregate.clear_changes!
        expect(aggregate.version).to eq 1
      end
    end

    context 'multiple state changes' do
      before do
        aggregate.add_item(OpenStruct.new(id: 1235))
        aggregate.add_item(OpenStruct.new(id: 1236))
      end

      it 'exposes the events in order' do
        emitted_versions = aggregate.changes.map { |e| e.body['id'] }
        expect(emitted_versions).to eq([1234, 1235, 1236])
      end

      it "increments it's version" do
        expect(aggregate.version).to eq 3
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
