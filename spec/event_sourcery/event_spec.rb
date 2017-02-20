RSpec.describe EventSourcery::Event do
  it 'initializes with data' do
    uuid = SecureRandom.uuid
    created_at = Time.now
    aggregate_id = SecureRandom.uuid
    body = { 'a' => 'b' }
    event = ItemAdded.new(id: 1, uuid: uuid, aggregate_id: aggregate_id, body: body, created_at: created_at)
    expect(event.id).to eq 1
    expect(event.uuid).to eq uuid
    expect(event.aggregate_id).to eq aggregate_id
    expect(event.body).to eq body
    expect(event.created_at).to eq created_at
  end

  describe '.type' do
    let(:serializer) { double }

    before do
      allow(EventSourcery.config).to receive(:event_type_serializer).and_return(serializer)
      allow(serializer).to receive(:serialize).and_return('serialized')
    end

    it 'delegates to the configured event type serializer' do
      EventSourcery::Event.type
      expect(serializer).to have_received(:serialize).with(EventSourcery::Event)
    end

    it 'returns the serialized type' do
      expect(EventSourcery::Event.type).to eq('serialized')
    end
  end

  describe '#type' do
    before do
      allow(EventSourcery::Event).to receive(:type).and_return(type)
    end

    context 'when the event class type is nil' do
      let(:type) { nil }

      it 'uses the provided type' do
        event = EventSourcery::Event.new(type: 'blah')
        expect(event.type).to eq 'blah'
      end
    end

    context 'when the event class type is not nil' do
      let(:type) { 'ItemAdded' }

      it "can't be overridden with the provided type" do
        event = EventSourcery::Event.new(type: 'blah')
        expect(event.type).to eq 'ItemAdded'
      end
    end
  end
end
