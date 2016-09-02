RSpec.describe EventSourcery::EventStore::Postgres::Connection do
  subject(:event_store) { described_class.new(pg_connection) }

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
end
