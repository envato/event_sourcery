RSpec.describe EventSourcery::EventProcessing::EventTrackers::Memory do
  let(:processor_name) { 'test-processor' }
  subject(:adapter) { described_class.new }

  it 'tracks processed events' do
    expect(adapter.last_processed_event_id(processor_name)).to eq 0
    adapter.processed_event(processor_name, 1)
    adapter.processed_event(processor_name, 2)
    expect(adapter.last_processed_event_id(processor_name)).to eq 2
  end
end
