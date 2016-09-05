RSpec.describe EventSourcery::EventStore::Postgres::Subscription do
  let(:on_new_event_callback) { proc {} }
  let(:event_types) { [] }
  subject(:subscription) { described_class.new(pg_connection: pg_connection,
                                               event_types: event_types,
                                               on_new_event: on_new_event_callback) }

end
