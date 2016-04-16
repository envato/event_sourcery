RSpec.describe ESFramework::EventSource do
  let(:events) { [] }
  let(:event_sink_adapter) { ESFramework::EventSinkAdapters::Memory.new(events) }
  let(:event_sink) { ESFramework::EventSink.new(event_sink_adapter) }
  subject(:event_store) { described_class.new(adapter) }

  describe 'adapter delegations' do
    let(:adapter) { double }

    before do
      allow(adapter).to receive(:get_next_from).and_return([])
      allow(adapter).to receive(:sink)
    end

    it 'delegates #get_next_from to the adapter' do
      result = event_store.get_next_from(1)
      expect(adapter).to have_received(:get_next_from).with(1)
    end
  end

  describe '#each_by_range' do
    let(:adapter) { ESFramework::EventSourceAdapters::Memory.new(events) }
    let(:aggregate_id) { SecureRandom.uuid }

    before do
      (1..2001).each do |i|
        event_sink.sink(aggregate_id: aggregate_id,
                        type: 'my_event',
                        body: {})
      end
    end

    context "the range doesn't include the latest event ID" do
      it 'returns only the events in the range' do
        events = []
        event_store.each_by_range(1, 20) do |event|
          events << event
        end
        expect(events.count).to eq 20
        expect(events.map(&:id)).to eq((1..20).to_a)
      end
    end

    context 'the range includes the latest event ID' do
      it 'returns all the events' do
        events = []
        event_store.each_by_range(1, 2001) do |event|
          events << event
        end
        expect(events.count).to eq 2001
        expect(events.map(&:id)).to eq((1..2001).to_a)
      end
    end

    context 'the range exceeds the latest event ID' do
      it 'returns all the events' do
        events = []
        event_store.each_by_range(1, 2050) do |event|
          events << event
        end
        expect(events.count).to eq 2001
        expect(events.map(&:id)).to eq((1..2001).to_a)
      end
    end
  end
end
