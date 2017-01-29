RSpec.describe EventSourcery::Event do
  let(:aggregate_id) { 'aggregate_id' }
  let(:type) { 'type' }
  let(:version) { 1 }
  let(:body) do
    {
      symbol: "value",
    }
  end
  let(:uuid) { SecureRandom.uuid }

  describe '#initialize' do
    subject(:initializer) { described_class.new(aggregate_id: aggregate_id, type: type, body: body, version: version) }

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

    context 'given version is a long string' do
      let(:version) { '1' * 20 }

      it 'version type is coerced to an integer value, bignum style' do
        expect(initializer.version).to eq(11_111_111_111_111_111_111)
      end
    end
  end

  context '.==' do
    subject { described_class.new(type: 'Type', body: { a: :b }) }

    it 'is equal to an event with the same type as a symbol and body' do
      is_expected.to eq described_class.new(type: :Type, body: { a: :b })
    end

    it 'is equal to an event with the same type as a string and body' do
      is_expected.to eq described_class.new(type: 'Type', body: { a: :b })
    end

    it 'is not equal to an event with a different type and the same body' do
      is_expected.not_to eq described_class.new(type: 'DifferentType', body: { a: :b })
    end

    it 'is not equal to an event with the same type and a different body' do
      is_expected.not_to eq described_class.new(type: 'Type', body: { different: :body })
    end
  end
end
