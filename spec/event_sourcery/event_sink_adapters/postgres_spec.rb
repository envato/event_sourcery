RSpec.describe EventSourcery::EventSinkAdapters::Postgres do
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

  def last_event
    events.last
  end

  def aggregate_version
    result = connection[:aggregates].
      where(aggregate_id: aggregate_id).
      first
    if result
      result[:version]
    end
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

  context 'optimistic concurrency control' do
    def sink_event(expected_version: nil)
      adapter.sink(aggregate_id: aggregate_id,
                   type: :billing_details_provided,
                   body: { my_event: 'data' },
                   expected_version: expected_version)
    end

    context "when the aggregate doesn't exist" do
      context 'and the expected version is correct - 0' do
        it 'saves the event with and sets the aggregate version to version 1' do
          sink_event(expected_version: 0)
          expect(last_event[:version]).to eq 1
          expect(aggregate_version).to eq 1
        end
      end

      context 'and the expected version is incorrect - 1' do
        it 'raises a ConcurrencyError' do
          expect {
            sink_event(expected_version: 1)
          }.to raise_error(EventSourcery::ConcurrencyError)
        end
      end

      context 'with no expected version' do
        it 'saves the event with and sets the aggregate version to version 1' do
          sink_event
          expect(last_event[:version]).to eq 1
          expect(aggregate_version).to eq 1
        end
      end
    end

    context 'when the aggregate exists' do
      before do
        add_event
      end

      context 'with an incorrect expected version - 0' do
        it 'raises a ConcurrencyError' do
          expect {
            sink_event(expected_version: 0)
          }.to raise_error(EventSourcery::ConcurrencyError)
        end
      end

      context 'with a correct expected version - 1' do
        it 'saves the event with and sets the aggregate version to version 2' do
          sink_event
          expect(last_event[:version]).to eq 2
          expect(aggregate_version).to eq 2
        end
      end

      context 'with no aggregate version' do
        it 'automatically sets the version on the event and aggregate' do
          sink_event
          expect(last_event[:version]).to eq 2
          expect(aggregate_version).to eq 2
        end
      end
    end

    context 'when a database error occurs that is not a concurrency error' do
      before do
        allow(connection).to receive(:run).and_raise(Sequel::DatabaseError)
      end

      it 'raises it' do
        expect { add_event }.to raise_error(Sequel::DatabaseError)
      end
    end
  end
end
