RSpec.describe Fountainhead::EventSourceAdapters::Postgres do
  let(:aggregate_id) { SecureRandom.uuid }
  let(:event_body) { { 'my_event' => 'data' } }
  let(:event_1) { Fountainhead::Event.new(id: 1, type: 'my_event', aggregate_id: aggregate_id, body: event_body) }
  let(:event_2) { Fountainhead::Event.new(id: 2, type: 'my_event', aggregate_id: aggregate_id, body: event_body) }
  subject(:adapter) { described_class.new(connection) }

  def add_event(aggregate_id:)
    connection[:events].
      insert(aggregate_id: aggregate_id,
             type: 'my_event',
             body: ::Sequel.pg_json(event_body))
  end

  def events
    @events ||= connection[:events].all
  end

  before do
    connection.execute('truncate table events')
    connection.execute('alter sequence events_id_seq restart with 1')
  end

  it 'gets a subset of events' do
    add_event(aggregate_id: aggregate_id)
    add_event(aggregate_id: aggregate_id)
    expect(adapter.get_next_from(1, 1).map(&:id)).to eq [1]
    expect(adapter.get_next_from(2, 1).map(&:id)).to eq [2]
    expect(adapter.get_next_from(1, 2).map(&:id)).to eq [1, 2]
  end

  it 'returns the event as expected' do
    add_event(aggregate_id: aggregate_id)
    event = adapter.get_next_from(1, 1).first
    expect(event.aggregate_id).to eq aggregate_id
    expect(event.type).to eq 'my_event'
    expect(event.body).to eq event_body
    expect(event.created_at).to be_instance_of(Time)
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
  end

  describe '#get_events_for_aggregate_id' do
    it 'gets events for a specific aggregate id' do
      add_event(aggregate_id: aggregate_id)
      add_event(aggregate_id: aggregate_id)
      add_event(aggregate_id: SecureRandom.uuid)
      events = adapter.get_events_for_aggregate_id(aggregate_id)
      expect(events.map(&:id)).to eq([1, 2])
      expect(events.first.aggregate_id).to eq aggregate_id
      expect(events.first.type).to eq 'my_event'
      expect(events.first.body).to eq event_body
      expect(events.first.created_at).to be_instance_of(Time)
    end
  end
end
