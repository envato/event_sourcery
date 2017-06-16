RSpec.describe EventSourcery::Memory::EventStore do
  let(:supports_versions) { false }
  subject(:event_store) { described_class.new([], event_builder: EventSourcery.config.event_builder) }

  include_examples 'an event store'

  it 'ignores an expected_version param' do
    expect {
      event_store.sink(EventSourcery::Event.new(type: 'blah', aggregate_id: SecureRandom.uuid, body: {}))
    }.to_not raise_error
  end
end
