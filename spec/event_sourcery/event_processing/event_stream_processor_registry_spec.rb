RSpec.describe EventSourcery::EventProcessing::EventStreamProcessorRegistry do
  subject(:registry) { described_class.new }
  let(:processor_1) { double(:processor_1, processor_name: 'processor_1') }
  let(:processor_2) { double(:processor_2, processor_name: 'processor_2') }

  before do
    registry.register(processor_1)
    registry.register(processor_2)
  end

  it 'registers ESPs by processor_name' do
    expect(registry.find('processor_1')).to eq processor_1
  end

  it 'returns all ESPs' do
    expect(registry.all).to eq [processor_1, processor_2]
  end
end
