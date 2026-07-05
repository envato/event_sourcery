# frozen_string_literal: true

RSpec.describe EventSourcery::EventStore::EventTypeSerializers::Legacy do
  subject(:serializer) { described_class.new }

  describe '#serialize' do
    it 'returns nil regardless of the event class' do
      expect(serializer.serialize(ItemAdded)).to be_nil
      expect(serializer.serialize(EventSourcery::Event)).to be_nil
    end
  end

  describe '#deserialize' do
    it 'always returns the base Event class' do
      expect(serializer.deserialize('item_added')).to eq EventSourcery::Event
      expect(serializer.deserialize('anything')).to eq EventSourcery::Event
    end
  end
end
