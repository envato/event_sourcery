RSpec.describe EventSourcery::EventStore::Memory do
  subject(:event_store) { described_class.new }

  include_examples 'an event store'
end
