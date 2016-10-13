RSpec.describe EventSourcery::EventProcessing::EventStreamProcessorRegistry do
  subject(:registry) { described_class.new }
  let(:projector) { Class.new { include EventSourcery::EventProcessing::Projector; processor_name 'projector' } }
  let(:reactor) { Class.new { include EventSourcery::EventProcessing::Reactor; processor_name 'reactor' } }

  before do
    registry.register(projector)
    registry.register(reactor)
  end

  it 'registers ESPs by processor_name' do
    expect(registry.find('projector')).to eq projector
    expect(registry.find('reactor')).to eq reactor
  end

  it 'returns all ESPs' do
    expect(registry.all).to eq [projector, reactor]
  end

  it 'can filter to projectors' do
    expect(registry.projectors).to eq [projector]
  end

  it 'can filter to reactors' do
    expect(registry.reactors).to eq [reactor]
  end
end
