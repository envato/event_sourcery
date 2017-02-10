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
    it 'returns the class name' do
      expect(ItemAdded.new.type).to eq 'ItemAdded'
      expect(ItemRemoved.new.type).to eq 'ItemRemoved'
    end

    it 'cannot be overridden with input' do
      expect(ItemAdded.new(type: 'Blah').type).to eq 'ItemAdded'
      expect(ItemRemoved.new(type: 'Blah').type).to eq 'ItemRemoved'
    end
  end
end
