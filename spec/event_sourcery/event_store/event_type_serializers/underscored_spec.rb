RSpec.describe EventSourcery::EventStore::EventTypeSerializers::Underscored do
  subject(:underscored) { described_class.new }

  describe '#serialize' do
    it 'returns nil always when the class is Event' do
      expect(underscored.serialize(EventSourcery::Event)).to eq nil
    end

    it 'returns the underscored class name' do
      expect(underscored.serialize(ItemAdded)).to eq 'item_added'
      expect(underscored.serialize(ItemRemoved)).to eq 'item_removed'
    end
  end

  describe '#deserialize' do
    it 'looks up the constant' do
      expect(underscored.deserialize('ItemAdded')).to eq ItemAdded
      expect(underscored.deserialize('ItemRemoved')).to eq ItemRemoved
    end

    it 'returns Event when not found' do
      expect(underscored.deserialize('ItemStarred')).to eq EventSourcery::Event
    end
  end
end
