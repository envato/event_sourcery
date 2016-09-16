RSpec.describe EventSourcery::EventStore::Postgres::Connection do
  subject(:event_store) { described_class.new(pg_connection) }

  before do
    create_old_events_schema
  end

  include_examples 'an event store'

  describe '#sink' do
    def add_event
      event_store.sink(new_event)
    end

    it 'notifies about a new event' do
      event_id = nil
      pg_connection.listen('new_event', loop: false, after_listen: proc { add_event }) do |channel, pid, payload|
        event_id = Integer(payload)
      end
    end
  end

  describe '#subscribe' do
    let(:aggregate_id) { SecureRandom.uuid }
    let(:event) { new_event(aggregate_id: aggregate_id) }

    it 'notifies of new events' do
      event_store.subscribe(from_id: 0, after_listen: proc { event_store.sink(event) }) do |events|
        @events = events
        throw :stop
      end
      expect(@events.count).to eq 1
      expect(@events.first.aggregate_id).to eq aggregate_id
    end
  end
end
