RSpec.describe EventSourcery::Memory::EventStore do
  let(:supports_versions) { false }
  let(:event) { EventSourcery::Event.new(type: 'blah', aggregate_id: SecureRandom.uuid, body: {}) }
  subject(:event_store) { described_class.new([], event_builder: EventSourcery.config.event_builder) }

  include_examples 'an event store'

  it 'ignores an expected_version param' do
    expect {
      event_store.sink(event)
    }.to_not raise_error
  end

  it 'passes events to listeners' do
    listener = Class.new do
      def process(event)
        @processed_event = event
      end
      attr_reader :processed_event
    end.new()
    event_store.add_listeners(listener)
    event_store.sink(event)
    expect(listener.processed_event).to eq(event)
  end
end
