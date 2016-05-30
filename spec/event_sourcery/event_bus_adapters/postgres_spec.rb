RSpec.describe EventSourcery::EventBusAdapters::Postgres do
  subject(:adapter) { described_class.new(connection) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:now) { Time.now }
  let(:event) { EventSourcery::Event.new(id: 123, aggregate_id: aggregate_id, type: :blah, body: { 'my' => 'body' }, created_at: now) }

  def publish_event
    adapter.publish(event)
  end

  describe '#publish' do
    it 'publishes a serialized event' do
      serialized_event = nil
      connection.listen('event', loop: false, after_listen: proc { publish_event }) do |channel, pid, payload|
        serialized_event = payload
      end
      deserialized_event = EventSourcery::Event.new(JSON.parse(serialized_event))
      # TODO: fix Event equality to make this nicer
      expect(deserialized_event.id).to eq event.id
      expect(deserialized_event.type).to eq event.type
      expect(deserialized_event.aggregate_id).to eq event.aggregate_id
      expect(deserialized_event.body).to eq event.body
      # investigate precision lost in JSON.dump
      # expect(deserialized_event.created_at).to eq event.created_at
    end
  end

  describe '#subscribe' do
    it 'subscribes to published events' do
      published_event = nil
      adapter.subscribe(loop: false, after_listen: proc { publish_event }) do |event|
        published_event = event
      end
      expect(published_event.id).to eq event.id
      expect(published_event.type).to eq event.type
      expect(published_event.aggregate_id).to eq event.aggregate_id
      expect(published_event.body).to eq event.body
    end
  end
end
