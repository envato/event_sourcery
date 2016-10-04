RSpec.describe EventSourcery::EventStore::Memory do
  let(:supports_versions) { false }
  subject(:event_store) { described_class.new }

  include_examples 'an event store'
end
