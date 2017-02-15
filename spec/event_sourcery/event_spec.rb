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

  describe '#type' do
    before do
      allow(EventSourcery.config).to receive(:event_type_serializer).and_return(event_type_serializer)
    end

    context 'with class name event type serializer' do
      let(:event_type_serializer) { EventSourcery::EventStore::EventTypeSerializers::ClassName.new }

      it 'returns the class name' do
        expect(ItemAdded.new.type).to eq 'ItemAdded'
        expect(ItemRemoved.new.type).to eq 'ItemRemoved'
      end

      it 'cannot be overridden with input' do
        expect(ItemAdded.new(type: 'Blah').type).to eq 'ItemAdded'
        expect(ItemRemoved.new(type: 'Blah').type).to eq 'ItemRemoved'
      end

      context 'when using the event class directly' do
        it 'returns nil' do
          expect(EventSourcery::Event.new.type).to be_nil
        end

        it 'allows type to be set' do
          expect(EventSourcery::Event.new(type: 'blah').type).to eq 'blah'
        end
      end
    end

    context 'with underscored event type serializer' do
      let(:event_type_serializer) { EventSourcery::EventStore::EventTypeSerializers::Underscored.new }

      it 'returns the class name' do
        expect(ItemAdded.new.type).to eq 'item_added'
        expect(ItemRemoved.new.type).to eq 'item_removed'
      end

      it 'cannot be overridden with input' do
        expect(ItemAdded.new(type: 'Blah').type).to eq 'item_added'
        expect(ItemRemoved.new(type: 'Blah').type).to eq 'item_removed'
      end

      context 'when using the event class directly' do
        it 'returns nil' do
          expect(EventSourcery::Event.new.type).to be_nil
        end

        it 'allows type to be set' do
          expect(EventSourcery::Event.new(type: 'blah').type).to eq 'blah'
        end
      end
    end

    context 'with legacy event type serializer' do
      let(:event_type_serializer) { EventSourcery::EventStore::EventTypeSerializers::Legacy.new }

      it 'returns the class name' do
        expect(ItemAdded.new.type).to be_nil
        expect(ItemRemoved.new.type).to be_nil
      end

      it 'can be overridden with input' do
        expect(ItemAdded.new(type: 'Blah').type).to eq 'Blah'
        expect(ItemRemoved.new(type: 'Blah').type).to eq 'Blah'
      end

      context 'when using the event class directly' do
        it 'returns nil' do
          expect(EventSourcery::Event.new.type).to be_nil
        end

        it 'allows type to be set' do
          expect(EventSourcery::Event.new(type: 'blah').type).to eq 'blah'
        end
      end
    end
  end
end
