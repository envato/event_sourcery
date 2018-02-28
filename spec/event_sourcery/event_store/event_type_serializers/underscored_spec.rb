RSpec.describe EventSourcery::EventStore::EventTypeSerializers::Underscored do
  subject(:underscored) { described_class.new }

  describe '#serialize' do
    it "doesn't handle Event in a special way" do
      expect(underscored.serialize(EventSourcery::Event)).to eq 'event_sourcery/event'
    end

    it 'returns the underscored class name' do
      expect(underscored.serialize(ItemAdded)).to eq 'item_added'
      expect(underscored.serialize(ItemRemoved)).to eq 'item_removed'
    end
  end

  describe '#deserialize' do
    it 'looks up the constant' do
      expect(underscored.deserialize('item_added')).to eq ItemAdded
      expect(underscored.deserialize('item_removed')).to eq ItemRemoved
    end

    it 'returns Event when not found' do
      expect(underscored.deserialize('item_starred')).to eq EventSourcery::Event
    end
  end
end
