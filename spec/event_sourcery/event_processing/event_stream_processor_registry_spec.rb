RSpec.describe EventSourcery::EventProcessing::EventStreamProcessorRegistry do
  subject(:registry) { described_class.new }
  let(:projector) { Class.new { include EventSourcery::EventProcessing::Projector; processor_name 'projector' } }
  let(:event_reactor) { Class.new { include EventSourcery::EventProcessing::EventReactor; processor_name 'event_reactor' } }

  before do
    registry.register(projector)
    registry.register(event_reactor)
  end

  it 'registers ESPs by processor_name' do
    expect(registry.find('projector')).to eq projector
    expect(registry.find('event_reactor')).to eq event_reactor
  end

  it 'returns all ESPs' do
    expect(registry.all).to eq [projector, event_reactor]
  end

  it 'can filter to projectors' do
    expect(registry.projectors).to eq [projector]
  end

  it 'can filter to event reactors' do
    expect(registry.event_reactors).to eq [event_reactor]
  end
end
