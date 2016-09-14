RSpec.describe EventSourcery::Event do
  let(:aggregate_id) { 'aggregate_id' }
  let(:type) { 'type' }
  let(:body) do
    {
      symbol: "value",
    }
  end

  describe '#initialize' do
    subject(:initializer) { described_class.new(aggregate_id: aggregate_id, type: type, body: body) }

    it 'converts body keys to strings' do
      expect(initializer.body.keys).to eq ["symbol"]
    end

    context 'key already a string' do
      let(:body) do
        {
          "string" => "value",
        }
      end

      it 'keeps string keys in body as strings' do
        expect(initializer.body.keys).to eq ["string"]
      end
    end

    context 'body is nil' do
      let(:body) { nil }

      it 'body is nil' do
        expect(initializer.body).to be_nil
      end
    end
  end

  context 'equality' do
    #let(:event_1) { EventSourcery::Event.new(id: 1
  end
end
