RSpec.describe EventSourcery::EventSourceAdapters::Postgres do
  let(:aggregate_id) { SecureRandom.uuid }
  let(:event_body) { { 'my_event' => 'data' } }
  let(:event_sink) { EventSourcery::EventSink.new(EventSourcery::EventSinkAdapters::Postgres.new(connection)) }
  let(:event_1) { EventSourcery::Event.new(id: 1, type: 'item_added', aggregate_id: aggregate_id, body: event_body) }
  let(:event_2) { EventSourcery::Event.new(id: 2, type: 'item_added', aggregate_id: aggregate_id, body: event_body) }
  subject(:adapter) { described_class.new(connection) }

  def add_event(aggregate_id:, type: 'item_added')
    event_sink.sink(aggregate_id: aggregate_id,
                    type: type,
                    body: event_body)
  end

  def events
    @events ||= connection[:events].all
  end

  before do
    connection.execute('truncate table events')
    connection.execute('truncate table aggregates')
    connection.execute('alter sequence events_id_seq restart with 1')
  end

  describe '#get_next_from' do
    it 'gets a subset of events' do
      add_event(aggregate_id: aggregate_id)
      add_event(aggregate_id: aggregate_id)
      expect(adapter.get_next_from(1, limit: 1).map(&:id)).to eq [1]
      expect(adapter.get_next_from(2, limit: 1).map(&:id)).to eq [2]
      expect(adapter.get_next_from(1, limit: 2).map(&:id)).to eq [1, 2]
    end

    it 'returns the event as expected' do
      add_event(aggregate_id: aggregate_id)
      event = adapter.get_next_from(1, limit: 1).first
      expect(event.aggregate_id).to eq aggregate_id
      expect(event.type).to eq 'item_added'
      expect(event.version).to eq 1
      expect(event.body).to eq event_body
      expect(event.created_at).to be_instance_of(Time)
    end

    it 'filters by event type' do
      add_event(aggregate_id: aggregate_id, type: 'user_signed_up')
      add_event(aggregate_id: aggregate_id, type: 'item_added')
      add_event(aggregate_id: aggregate_id, type: 'item_added')
      add_event(aggregate_id: aggregate_id, type: 'item_rejected')
      add_event(aggregate_id: aggregate_id, type: 'user_signed_up')
      events = adapter.get_next_from(1, event_types: ['user_signed_up'])
      expect(events.count).to eq 2
      expect(events.map(&:id)).to eq [1, 5]
    end
  end

  describe '#latest_event_id' do
    it 'returns the latest event id' do
      add_event(aggregate_id: aggregate_id)
      add_event(aggregate_id: aggregate_id)
      expect(adapter.latest_event_id).to eq 2
    end

    context 'with no events' do
      it 'returns 0' do
        expect(adapter.latest_event_id).to eq 0
      end
    end

    context 'with event type filtering' do
      it 'gets the latest event ID for a set of event types' do
        add_event(aggregate_id: aggregate_id, type: 'type_1')
        add_event(aggregate_id: aggregate_id, type: 'type_1')
        add_event(aggregate_id: aggregate_id, type: 'type_2')

        expect(adapter.latest_event_id(event_types: ['type_1'])).to eq 2
        expect(adapter.latest_event_id(event_types: ['type_2'])).to eq 3
        expect(adapter.latest_event_id(event_types: ['type_1', 'type_2'])).to eq 3
      end
    end
  end

  describe '#get_events_for_aggregate_id' do
    it 'gets events for a specific aggregate id' do
      add_event(aggregate_id: aggregate_id)
      add_event(aggregate_id: aggregate_id)
      add_event(aggregate_id: SecureRandom.uuid)
      events = adapter.get_events_for_aggregate_id(aggregate_id)
      expect(events.map(&:id)).to eq([1, 2])
      expect(events.first.aggregate_id).to eq aggregate_id
      expect(events.first.type).to eq 'item_added'
      expect(events.first.body).to eq event_body
      expect(events.first.created_at).to be_instance_of(Time)
    end
  end
end
