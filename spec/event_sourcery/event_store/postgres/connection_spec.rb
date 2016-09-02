RSpec.describe EventSourcery::EventStore::Postgres::Connection do
  subject(:event_store) { described_class.new(pg_connection) }

  include_examples 'an event store'
end
