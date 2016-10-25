RSpec.shared_examples 'an event store' do
  let(:aggregate_id) { SecureRandom.uuid }

  describe '#sink' do
    it 'assigns auto incrementing event IDs' do
      event_store.sink(new_event)
      event_store.sink(new_event)
      event_store.sink(new_event)
      events = event_store.get_next_from(1)
      expect(events.count).to eq 3
      expect(events.map(&:id)).to eq [1, 2, 3]
    end

    it 'assigns UUIDs' do
      uuid = SecureRandom.uuid
      event_store.sink(new_event(uuid: uuid))
      event = event_store.get_next_from(1).first
      expect(event.uuid).to eq uuid
    end

    it 'returns true' do
      expect(event_store.sink(new_event)).to eq true
    end

    it 'serializes the event body' do
      time = Time.now
      event = new_event(body: { 'time' => time })
      expect(event_store.sink(event)).to eq true
      expect(event_store.get_next_from(1, limit: 1).first.body).to eq('time' => time.iso8601)
    end

    it 'writes multiple events' do
      event_store.sink([new_event(aggregate_id: aggregate_id, body: {e: 1}),
                        new_event(aggregate_id: aggregate_id, body: {e: 2}),
                        new_event(aggregate_id: aggregate_id, body: {e: 3})])
      events = event_store.get_next_from(1)
      expect(events.count).to eq 3
      expect(events.map(&:id)).to eq [1, 2, 3]
      expect(events.map(&:body)).to eq [{'e' => 1}, {'e' => 2}, {'e' => 3}]
      if supports_versions
        expect(events.map(&:version)).to eq [1, 2, 3]
      end
    end

    it 'sets the correct aggregates version' do
      event_store.sink([new_event(aggregate_id: aggregate_id, body: {e: 1}),
                        new_event(aggregate_id: aggregate_id, body: {e: 2})])
      # this will throw a unique constrain error if the aggregate version was not set correctly ^
      event_store.sink([new_event(aggregate_id: aggregate_id, body: {e: 1}),
                        new_event(aggregate_id: aggregate_id, body: {e: 2})])
      events = event_store.get_next_from(1)
      expect(events.count).to eq 4
      expect(events.map(&:id)).to eq [1, 2, 3, 4]
    end

    context 'with no existing aggregate stream' do
      it 'saves an event' do
        event = new_event(aggregate_id: aggregate_id,
                          type: :test_event_2,
                          body: { 'my' => 'data' })
        event_store.sink(event)
        events = event_store.get_next_from(1)
        expect(events.count).to eq 1
        expect(events.first.id).to eq 1
        expect(events.first.aggregate_id).to eq aggregate_id
        expect(events.first.type).to eq 'test_event_2'
        expect(events.first.body).to eq({ 'my' => 'data' }) # should we symbolize keys when hydrating events?
      end
    end

    context 'with an existing aggregate stream' do
      before do
        event_store.sink(new_event(aggregate_id: aggregate_id))
      end

      it 'saves an event' do
        event = new_event(aggregate_id: aggregate_id,
                         type: :test_event_2,
                         body: { 'my' => 'data' })
        event_store.sink(event)
        events = event_store.get_next_from(1)
        expect(events.count).to eq 2
        expect(events.last.id).to eq 2
        expect(events.last.aggregate_id).to eq aggregate_id
        expect(events.last.type).to eq :test_event_2.to_s # shouldn't you get back what you put in, a symbol?
        expect(events.last.body).to eq({ 'my' => 'data' }) # should we symbolize keys when hydrating events?
      end
    end
  end

  describe '#get_next_from' do
    it 'gets a subset of events' do
      event_store.sink(new_event(aggregate_id: aggregate_id))
      event_store.sink(new_event(aggregate_id: aggregate_id))
      expect(event_store.get_next_from(1, limit: 1).map(&:id)).to eq [1]
      expect(event_store.get_next_from(2, limit: 1).map(&:id)).to eq [2]
      expect(event_store.get_next_from(1, limit: 2).map(&:id)).to eq [1, 2]
    end

    it 'returns the event as expected' do
      event_store.sink(new_event(aggregate_id: aggregate_id, type: 'item_added', body: { 'my' => 'data' }))
      event = event_store.get_next_from(1, limit: 1).first
      expect(event.aggregate_id).to eq aggregate_id
      expect(event.type).to eq 'item_added'
      expect(event.body).to eq({ 'my' => 'data' })
      expect(event.created_at).to be_instance_of(Time)
    end

    it 'filters by event type' do
      event_store.sink(new_event(aggregate_id: aggregate_id, type: 'user_signed_up'))
      event_store.sink(new_event(aggregate_id: aggregate_id, type: 'item_added'))
      event_store.sink(new_event(aggregate_id: aggregate_id, type: 'item_added'))
      event_store.sink(new_event(aggregate_id: aggregate_id, type: 'item_rejected'))
      event_store.sink(new_event(aggregate_id: aggregate_id, type: 'user_signed_up'))
      events = event_store.get_next_from(1, event_types: ['user_signed_up'])
      expect(events.count).to eq 2
      expect(events.map(&:id)).to eq [1, 5]
    end
  end

  describe '#latest_event_id' do
    it 'returns the latest event id' do
      event_store.sink(new_event(aggregate_id: aggregate_id))
      event_store.sink(new_event(aggregate_id: aggregate_id))
      expect(event_store.latest_event_id).to eq 2
    end

    context 'with no events' do
      it 'returns 0' do
        expect(event_store.latest_event_id).to eq 0
      end
    end

    context 'with event type filtering' do
      it 'gets the latest event ID for a set of event types' do
        event_store.sink(new_event(aggregate_id: aggregate_id, type: 'type_1'))
        event_store.sink(new_event(aggregate_id: aggregate_id, type: 'type_1'))
        event_store.sink(new_event(aggregate_id: aggregate_id, type: 'type_2'))

        expect(event_store.latest_event_id(event_types: ['type_1'])).to eq 2
        expect(event_store.latest_event_id(event_types: ['type_2'])).to eq 3
        expect(event_store.latest_event_id(event_types: ['type_1', 'type_2'])).to eq 3
      end
    end
  end

  describe '#get_events_for_aggregate_id' do
    it 'gets events for a specific aggregate id' do
      event_store.sink(new_event(aggregate_id: aggregate_id, type: 'item_added', body: { 'my' => 'body' }))
      event_store.sink(new_event(aggregate_id: aggregate_id))
      event_store.sink(new_event(aggregate_id: SecureRandom.uuid))
      events = event_store.get_events_for_aggregate_id(aggregate_id)
      expect(events.map(&:id)).to eq([1, 2])
      expect(events.first.aggregate_id).to eq aggregate_id
      expect(events.first.type).to eq 'item_added'
      expect(events.first.body).to eq({ 'my' => 'body' })
      expect(events.first.created_at).to be_instance_of(Time)
    end
  end

  # TODO: this is a slow spec, optimise
  describe '#each_by_range' do
    before do
      (1..2001).each do |i|
        event_store.sink(new_event(aggregate_id: aggregate_id,
                                   type: 'item_added',
                                   body: {}))
      end
    end

    def events_by_range(*args)
      [].tap do |events|
        event_store.each_by_range(*args) do |event|
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
