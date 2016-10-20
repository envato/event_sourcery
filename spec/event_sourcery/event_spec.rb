RSpec.describe EventSourcery::Event do
  let(:aggregate_id) { 'aggregate_id' }
  let(:type) { 'type' }
  let(:body) do
    {
      symbol: "value",
    }
  end
  let(:uuid) { SecureRandom.uuid }

  describe '#initialize' do
    subject(:initializer) { described_class.new(aggregate_id: aggregate_id, type: type, body: body) }

    before do
      allow(EventSourcery::EventBodySerializer).to receive(:serialize)
    end

    it 'serializes event body' do
      expect(EventSourcery::EventBodySerializer).to receive(:serialize).with(body)
      initializer
    end

    it 'assigns a uuid if one is not given' do
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
      expect(initializer.uuid).to eq uuid
    end

    it 'assigns given uuids' do
      uuid = SecureRandom.uuid
      expect(described_class.new(uuid: uuid).uuid).to eq uuid
    end

    context 'event body is nil' do
      let(:body) { nil }

      it 'skips serialization of event body' do
        expect(EventSourcery::EventBodySerializer).to_not receive(:serialize)
        initializer
      end
    end
  end

  context 'equality' do
    #let(:event_1) { EventSourcery::Event.new(id: 1
  end
end
