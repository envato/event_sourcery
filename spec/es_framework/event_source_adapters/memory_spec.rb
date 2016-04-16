RSpec.describe ESFramework::EventSourceAdapters::Memory do
  let(:aggregate_id) { SecureRandom.uuid }
  let(:event_1) { ESFramework::Event.new(id: 1, type: 'billing_details_provided', aggregate_id: aggregate_id, body: {}) }
  let(:event_2) { ESFramework::Event.new(id: 2, type: 'billing_details_provided', aggregate_id: aggregate_id, body: {}) }
  let(:event_3) { ESFramework::Event.new(id: 3, type: 'billing_details_provided', aggregate_id: SecureRandom.uuid, body: {}) }
  let(:events) { [event_1, event_2] }
  subject(:adapter) { described_class.new(events) }

  it 'gets a subset of events' do
    expect(adapter.get_next_from(1, 1)).to eq [event_1]
    expect(adapter.get_next_from(2, 1)).to eq [event_2]
    expect(adapter.get_next_from(1, 2)).to eq [event_1, event_2]
  end

  it 'gets events for a specific aggregate' do
    expect(adapter.get_events_for_aggregate_id(aggregate_id)).to eq [event_1, event_2]
  end
end

