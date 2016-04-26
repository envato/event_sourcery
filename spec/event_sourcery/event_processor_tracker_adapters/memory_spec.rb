RSpec.describe EventSourcery::EventProcessorTrackerAdapters::Memory do
  let(:processor_name) { 'test-processor' }
  subject(:adapter) { described_class.new }

  it 'tracks processed events' do
    expect(adapter.last_processed_event_id(processor_name)).to eq 0
    adapter.processing_event(processor_name, 1) do
    end
    adapter.processing_event(processor_name, 2) do
    end
    expect(adapter.last_processed_event_id(processor_name)).to eq 2
  end
end
