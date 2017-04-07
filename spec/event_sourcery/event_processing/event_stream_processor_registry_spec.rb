module MyProjector
  def self.included(base)
    base.send(:include, EventSourcery::EventProcessing::EventStreamProcessor)
  end
end
module MyReactor
  def self.included(base)
    base.send(:include, EventSourcery::EventProcessing::EventStreamProcessor)
  end
end

RSpec.describe EventSourcery::EventProcessing::EventStreamProcessorRegistry do
  subject(:registry) { described_class.new }

  let(:projector) { Class.new { include MyProjector; processor_name 'projector' } }
  let(:reactor) { Class.new { include MyReactor; processor_name 'reactor' } }

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

  it 'can filter by type' do
    expect(registry.by_type(MyProjector)).to eq [projector]
  end

  it 'can filter to reactors' do
    expect(registry.by_type(MyReactor)).to eq [reactor]
  end
end
