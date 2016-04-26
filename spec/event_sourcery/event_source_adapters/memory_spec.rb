RSpec.describe EventSourcery::EventSourceAdapters::Memory do
  let(:aggregate_id) { SecureRandom.uuid }
  let(:event_1) { EventSourcery::Event.new(id: 1, type: 'user_signed_up', aggregate_id: aggregate_id, body: {}) }
  let(:event_2) { EventSourcery::Event.new(id: 2, type: 'item_added', aggregate_id: aggregate_id, body: {}) }
  let(:event_3) { EventSourcery::Event.new(id: 3, type: 'user_signed_up', aggregate_id: SecureRandom.uuid, body: {}) }
  let(:events) { [event_1, event_2, event_3] }
  subject(:adapter) { described_class.new(events) }

  it 'gets a subset of events' do
    expect(adapter.get_next_from(1, limit: 1)).to eq [event_1]
    expect(adapter.get_next_from(2, limit: 1)).to eq [event_2]
    expect(adapter.get_next_from(1, limit: 2)).to eq [event_1, event_2]
  end

  it 'filters by event type' do
    expect(adapter.get_next_from(1, event_type: 'user_signed_up', limit: 1)).to eq [event_1]
    expect(adapter.get_next_from(1, event_type: 'user_signed_up')).to eq [event_1, event_3]
  end

  it 'gets events for a specific aggregate' do
    expect(adapter.get_events_for_aggregate_id(aggregate_id)).to eq [event_1, event_2]
  end
end

