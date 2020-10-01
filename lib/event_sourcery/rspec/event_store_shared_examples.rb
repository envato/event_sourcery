RSpec.shared_examples 'an event store' do
  TestEvent2 = Class.new(EventSourcery::Event)
  UserSignedUp = Class.new(EventSourcery::Event)
  ItemRejected = Class.new(EventSourcery::Event)
  Type1 = Class.new(EventSourcery::Event)
  Type2 = Class.new(EventSourcery::Event)
  BillingDetailsProvided = Class.new(EventSourcery::Event)

  let(:aggregate_id) { SecureRandom.uuid }

  describe '#sink' do
    it 'assigns auto incrementing event IDs' do
      event_store.sink(ItemAdded.new(aggregate_id: SecureRandom.uuid))
      event_store.sink(ItemAdded.new(aggregate_id: SecureRandom.uuid))
      event_store.sink(ItemAdded.new(aggregate_id: SecureRandom.uuid))
      events = event_store.get_next_from(1)
      expect(events.count).to eq 3
      expect(events.map(&:id)).to eq [1, 2, 3]
    end

    it 'assigns UUIDs' do
      uuid = SecureRandom.uuid
      event_store.sink(ItemAdded.new(aggregate_id: SecureRandom.uuid, uuid: uuid))
      event = event_store.get_next_from(1).first
      expect(event.uuid).to eq uuid
    end

    it 'returns true' do
      expect(event_store.sink(ItemAdded.new(aggregate_id: SecureRandom.uuid))).to eq true
    end

    it 'serializes the event body' do
      time = Time.now
      event = ItemAdded.new(aggregate_id: SecureRandom.uuid, body: { 'time' => time })
      expect(event_store.sink(event)).to eq true
      expect(event_store.get_next_from(1, limit: 1).first.body).to eq('time' => time.iso8601)
    end

    it 'saves the causation_id' do
      causation_id = SecureRandom.uuid
      event = ItemAdded.new(aggregate_id: SecureRandom.uuid, causation_id: causation_id)
      event_store.sink(event)
      expect(event_store.get_next_from(1, limit: 1).first.causation_id).to eq(causation_id)
    end

    it 'saves the correlation_id' do
      correlation_id = SecureRandom.uuid
      event = ItemAdded.new(aggregate_id: SecureRandom.uuid, correlation_id: correlation_id)
      event_store.sink(event)
      expect(event_store.get_next_from(1, limit: 1).first.correlation_id).to eq(correlation_id)
    end

    it 'writes multiple events' do
      event_store.sink([ItemAdded.new(aggregate_id: aggregate_id, body: {e: 1}),
                        ItemAdded.new(aggregate_id: aggregate_id, body: {e: 2}),
                        ItemAdded.new(aggregate_id: aggregate_id, body: {e: 3})])
      events = event_store.get_next_from(1)
      expect(events.count).to eq 3
      expect(events.map(&:id)).to eq [1, 2, 3]
      expect(events.map(&:body)).to eq [{'e' => 1}, {'e' => 2}, {'e' => 3}]
      expect(events.map(&:version)).to eq [1, 2, 3]
    end

    it 'sets the correct aggregates version' do
      event_store.sink([ItemAdded.new(aggregate_id: aggregate_id, body: {e: 1}),
                        ItemAdded.new(aggregate_id: aggregate_id, body: {e: 2})])
      # this will throw a unique constrain error if the aggregate version was not set correctly ^
      event_store.sink([ItemAdded.new(aggregate_id: aggregate_id, body: {e: 1}),
                        ItemAdded.new(aggregate_id: aggregate_id, body: {e: 2})])
      events = event_store.get_next_from(1)
      expect(events.count).to eq 4
      expect(events.map(&:id)).to eq [1, 2, 3, 4]
    end

    context 'with no existing aggregate stream' do
      it 'saves an event' do
        event = TestEvent2.new(aggregate_id: aggregate_id, body: { 'my' => 'data' })
        event_store.sink(event)
        events = event_store.get_next_from(1)
        expect(events.count).to eq 1
        expect(events.first.id).to eq 1
        expect(events.first.aggregate_id).to eq aggregate_id
        expect(events.first.type).to eq 'test_event2'
        expect(events.first.body).to eq({ 'my' => 'data' }) # should we symbolize keys when hydrating events?
      end
    end

    context 'with an existing aggregate stream' do
      before do
        event_store.sink(ItemAdded.new(aggregate_id: aggregate_id))
      end

      it 'saves an event' do
        event = TestEvent2.new(aggregate_id: aggregate_id, body: { 'my' => 'data' })
        event_store.sink(event)
        events = event_store.get_next_from(1)
        expect(events.count).to eq 2
        expect(events.last.id).to eq 2
        expect(events.last.aggregate_id).to eq aggregate_id
        expect(events.last.type).to eq :test_event2.to_s # shouldn't you get back what you put in, a symbol?
        expect(events.last.body).to eq({ 'my' => 'data' }) # should we symbolize keys when hydrating events?
      end
    end

    it 'correctly inserts created at times when inserting multiple events atomically' do
      time = Time.parse('2016-10-14T00:00:00.646191Z')
      event_store.sink([ItemAdded.new(aggregate_id: aggregate_id, created_at: nil), ItemAdded.new(aggregate_id: aggregate_id, created_at: time)])
      created_ats = event_store.get_next_from(0).map(&:created_at)
      expect(created_ats.map(&:class)).to eq [Time, Time]
      expect(created_ats.last).to eq time
    end

    it 'raises an error if the events given are for more than one aggregate' do
      expect {
        event_store.sink([ItemAdded.new(aggregate_id: aggregate_id), ItemAdded.new(aggregate_id: SecureRandom.uuid)])
      }.to raise_error(EventSourcery::AtomicWriteToMultipleAggregatesNotSupported)
    end
  end

  describe '#get_next_from' do
    it 'gets a subset of events' do
      event_store.sink(ItemAdded.new(aggregate_id: aggregate_id))
      event_store.sink(ItemAdded.new(aggregate_id: aggregate_id))
      expect(event_store.get_next_from(1, limit: 1).map(&:id)).to eq [1]
      expect(event_store.get_next_from(2, limit: 1).map(&:id)).to eq [2]
      expect(event_store.get_next_from(1, limit: 2).map(&:id)).to eq [1, 2]
    end

    it 'returns the event as expected' do
      event_store.sink(ItemAdded.new(aggregate_id: aggregate_id, body: { 'my' => 'data' }))
      event = event_store.get_next_from(1, limit: 1).first
      expect(event.aggregate_id).to eq aggregate_id
      expect(event.type).to eq 'item_added'
      expect(event.body).to eq({ 'my' => 'data' })
      expect(event.created_at).to be_instance_of(Time)
    end

    it 'filters by event type' do
      event_store.sink(UserSignedUp.new(aggregate_id: aggregate_id))
      event_store.sink(ItemAdded.new(aggregate_id: aggregate_id))
      event_store.sink(ItemAdded.new(aggregate_id: aggregate_id))
      event_store.sink(ItemRejected.new(aggregate_id: aggregate_id))
      event_store.sink(UserSignedUp.new(aggregate_id: aggregate_id))
      events = event_store.get_next_from(1, event_types: ['user_signed_up'])
      expect(events.count).to eq 2
      expect(events.map(&:id)).to eq [1, 5]
    end
  end

  describe '#latest_event_id' do
    it 'returns the latest event id' do
      event_store.sink(ItemAdded.new(aggregate_id: aggregate_id))
      event_store.sink(ItemAdded.new(aggregate_id: aggregate_id))
      expect(event_store.latest_event_id).to eq 2
    end

    context 'with no events' do
      it 'returns 0' do
        expect(event_store.latest_event_id).to eq 0
      end
    end

    context 'with event type filtering' do
      it 'gets the latest event ID for a set of event types' do
        event_store.sink(Type1.new(aggregate_id: aggregate_id))
        event_store.sink(Type1.new(aggregate_id: aggregate_id))
        event_store.sink(Type2.new(aggregate_id: aggregate_id))

        expect(event_store.latest_event_id(event_types: ['type1'])).to eq 2
        expect(event_store.latest_event_id(event_types: ['type2'])).to eq 3
        expect(event_store.latest_event_id(event_types: ['type1', 'type2'])).to eq 3
      end
    end
  end

  describe '#get_events_for_aggregate_id' do
    RSpec.shared_examples 'gets events for a specific aggregate id' do
      before do
        event_store.sink(ItemAdded.new(aggregate_id: aggregate_id, body: { 'my' => 'body' }))
        event_store.sink(ItemAdded.new(aggregate_id: double(to_str: aggregate_id)))
        event_store.sink(ItemAdded.new(aggregate_id: SecureRandom.uuid))
      end

      subject(:events) { event_store.get_events_for_aggregate_id(uuid) }

      specify do
        expect(events.map(&:id)).to eq([1, 2])
        expect(events.first.aggregate_id).to eq aggregate_id
        expect(events.first.type).to eq 'item_added'
        expect(events.first.body).to eq({ 'my' => 'body' })
        expect(events.first.created_at).to be_instance_of(Time)
      end
    end

    context 'when aggregate_id is a string' do
      include_examples 'gets events for a specific aggregate id' do
        let(:uuid) { aggregate_id }
      end
    end

    context 'when aggregate_id is convertible to a string' do
      include_examples 'gets events for a specific aggregate id' do
        let(:uuid) { double(to_str: aggregate_id) }
      end
    end
  end

  describe '#each_by_range' do
    before do
      (1..21).each do |i|
        event_store.sink(ItemAdded.new(aggregate_id: aggregate_id, body: {}))
      end
    end

    def events_by_range(from_event_id, to_event_id, **args)
      [].tap do |events|
        event_store.each_by_range(from_event_id, to_event_id, **args) do |event|
          events << event
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
        events = events_by_range(1, 21)
        expect(events.count).to eq 21
        expect(events.map(&:id)).to eq((1..21).to_a)
      end
    end

    context 'the range exceeds the latest event ID' do
      it 'returns all the events' do
        events = events_by_range(1, 25)
        expect(events.count).to eq 21
        expect(events.map(&:id)).to eq((1..21).to_a)
      end
    end

    context 'the range filters by event type' do
      it 'returns only events of the given type' do
        expect(events_by_range(1, 21, event_types: ['user_signed_up']).count).to eq 0
        expect(events_by_range(1, 21, event_types: ['item_added']).count).to eq 21
      end
    end
  end

  def save_event(expected_version: nil)
    event_store.sink(
      BillingDetailsProvided.new(aggregate_id: aggregate_id, body: { my_event: 'data' }),
      expected_version: expected_version,
    )
  end

  def add_event
    event_store.sink(ItemAdded.new(aggregate_id: aggregate_id))
  end

  def last_event
    event_store.get_next_from(0).last
  end

  context 'optimistic concurrency control' do
    context "when the aggregate doesn't exist" do
      context 'and the expected version is correct - 0' do
        it 'saves the event with and sets the aggregate version to version 1' do
          save_event(expected_version: 0)
          expect(last_event.version).to eq 1
        end
      end

      context 'and the expected version is incorrect - 1' do
        it 'raises a ConcurrencyError' do
          expect {
            save_event(expected_version: 1)
          }.to raise_error(EventSourcery::ConcurrencyError)
        end
      end

      context 'with no expected version' do
        it 'saves the event with and sets the aggregate version to version 1' do
          save_event
          expect(last_event.version).to eq 1
        end
      end
    end

    context 'when the aggregate exists' do
      before do
        add_event
      end

      context 'with an incorrect expected version - 0' do
        it 'raises a ConcurrencyError' do
          expect {
            save_event(expected_version: 0)
          }.to raise_error(EventSourcery::ConcurrencyError)
        end
      end

      context 'with a correct expected version - 1' do
        it 'saves the event with and sets the aggregate version to version 2' do
          save_event
          expect(last_event.version).to eq 2
        end
      end

      context 'with no aggregate version' do
        it 'automatically sets the version on the event and aggregate' do
          save_event
          expect(last_event.version).to eq 2
        end
      end
    end

    it 'allows overriding the created_at timestamp for events' do
      time = Time.parse('2016-10-14T00:00:00.646191Z')
      event_store.sink(BillingDetailsProvided.new(aggregate_id: aggregate_id,
                                                  body: { my_event: 'data' },
                                                  created_at: time))
      expect(last_event.created_at).to eq time
    end

    it "sets a created_at time when one isn't provided in the event" do
      event_store.sink(BillingDetailsProvided.new(aggregate_id: aggregate_id,
                                                  body: { my_event: 'data' }))
      expect(last_event.created_at).to be_instance_of(Time)
    end
  end
end
