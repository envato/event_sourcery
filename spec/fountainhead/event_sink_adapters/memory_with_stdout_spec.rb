RSpec.describe Fountainhead::EventSinkAdapters::MemoryWithStdOut do
  let(:events) { [] }
  subject(:adapter) { described_class.new(events, io) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:io) { StringIO.new }

  def add_event
    adapter.sink(aggregate_id: aggregate_id,
                 type: 'billing_details_provided',
                 body: { my_event: 'data' })
  end

  it 'writes the event to STDOUT' do
    add_event
    expect(io.string).to eq "#{aggregate_id},billing_details_provided,{\"my_event\":\"data\"}\n"
  end
end
