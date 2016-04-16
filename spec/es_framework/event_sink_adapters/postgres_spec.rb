RSpec.describe ESFramework::EventSinkAdapters::Postgres do
  subject(:adapter) { described_class.new(connection) }
  let(:aggregate_id) { SecureRandom.uuid }

  def add_event
    adapter.sink(aggregate_id: aggregate_id,
                 type: :billing_details_provided,
                 body: { my_event: 'data' })
  end

  def events
    @events ||= connection[:events].all
  end

  before do
    connection.execute('truncate table events')
    connection.execute('alter sequence events_id_seq restart with 1')
  end

  it 'adds events with the given data' do
    add_event
    expect(events.size).to eq 1
    expect(events.first[:aggregate_id]).to eq aggregate_id
    expect(events.first[:type]).to eq 'billing_details_provided'
    expect(events.first[:body]).to eq({ 'my_event' => 'data' })
  end

  it 'assigns auto incrementing identifiers' do
    add_event
    add_event
    expect(events.size).to eq 2
    expect(events.map { |e| e[:id] }).to eq [1, 2]
  end

  it 'notifies about a new event' do
    event_id = nil
    connection.listen('new_event', loop: false, after_listen: proc { add_event }) do |channel, pid, payload|
      event_id = Integer(payload)
    end
  end

  it 'returns true' do
    expect(add_event).to eq true
  end
end
