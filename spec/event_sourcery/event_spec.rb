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

    before do
      allow(EventSourcery::EventBodySerializer).to receive(:serialize)
    end

    it 'serializes event body' do
      expect(EventSourcery::EventBodySerializer).to receive(:serialize).with(body)
      initializer
    end
  end

  context 'equality' do
    #let(:event_1) { EventSourcery::Event.new(id: 1
  end
end
