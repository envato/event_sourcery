RSpec.describe ESFramework::EventSinkAdapters::Memory do
  let(:events) { [] }
  subject(:adapter) { described_class.new(events) }
  let(:aggregate_id) { SecureRandom.uuid }

  def add_event
    adapter.sink(aggregate_id: aggregate_id,
                 type: 'billing_details_provided',
                 body: { my_event: 'data' })
  end

  it 'adds events with the given data' do
    add_event
    expect(events.size).to eq 1
    expect(events.first[:aggregate_id]).to eq aggregate_id
    expect(events.first[:type]).to eq 'billing_details_provided'
    expect(events.first[:body]).to eq({ my_event: 'data' })
  end

  it 'assigns auto incrementing identifiers' do
    add_event
    add_event
    expect(events.size).to eq 2
    expect(events.map { |e| e[:id] }).to eq [1, 2]
  end

  it 'returns true' do
    expect(add_event).to eq true
  end
end
