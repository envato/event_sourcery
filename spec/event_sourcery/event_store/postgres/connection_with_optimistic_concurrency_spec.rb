RSpec.describe EventSourcery::EventStore::Postgres::ConnectionWithOptimisticConcurrency do
  let(:supports_versions) { true }
  subject(:event_store) { described_class.new(pg_connection) }
  let(:aggregate_id) { SecureRandom.uuid }

  include_examples 'an event store'

  def save_event(expected_version: nil)
    event_store.sink(new_event(aggregate_id: aggregate_id,
                     type: :billing_details_provided,
                     body: { my_event: 'data' }),
                     expected_version: expected_version)
  end

  def add_event
    event_store.sink(new_event(aggregate_id: aggregate_id))
  end

  def last_event
    event_store.get_next_from(0).last
  end

  def aggregate_version
    result = connection[:aggregates].
      where(aggregate_id: aggregate_id).
      first
    if result
      result[:version]
    end
  end

  describe '#sink' do
    def add_event
      event_store.sink(new_event)
    end

    it 'notifies about a new event' do
      event_id = nil
      pg_connection.listen('new_event', loop: false, after_listen: proc { add_event }) do |channel, pid, payload|
        event_id = Integer(payload)
      end
    end
  end

  describe '#subscribe' do
    let(:event) { new_event(aggregate_id: aggregate_id) }

    it 'notifies of new events' do
      event_store.subscribe(from_id: 0, after_listen: proc { event_store.sink(event) }) do |events|
        @events = events
        throw :stop
      end
      expect(@events.count).to eq 1
      expect(@events.first.aggregate_id).to eq aggregate_id
    end
  end

  context 'optimistic concurrency control' do
    context "when the aggregate doesn't exist" do
      context 'and the expected version is correct - 0' do
        it 'saves the event with and sets the aggregate version to version 1' do
          save_event(expected_version: 0)
          expect(last_event[:version]).to eq 1
          expect(aggregate_version).to eq 1
        end
      end

      context 'and the expected version is incorrect - 1' do
        it 'raises a ConcurrencyError' do
          expect {
            save_event(expected_version: 1)
          }.to raise_error(EventSourcery::ConcurrencyError)
        end
      end

      context 'with no expected version' do
        it 'saves the event with and sets the aggregate version to version 1' do
          save_event
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
            save_event(expected_version: 0)
          }.to raise_error(EventSourcery::ConcurrencyError)
        end
      end

      context 'with a correct expected version - 1' do
        it 'saves the event with and sets the aggregate version to version 2' do
          save_event
          expect(last_event[:version]).to eq 2
          expect(aggregate_version).to eq 2
        end
      end

      context 'with no aggregate version' do
        it 'automatically sets the version on the event and aggregate' do
          save_event
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

    it 'allows overriding the created_at timestamp for events' do
      time = Time.parse('2016-10-14T00:00:00.646191Z')
      event_store.sink(new_event(aggregate_id: aggregate_id,
                                 type: :billing_details_provided,
                                 body: { my_event: 'data' },
                                 created_at: time))
      expect(last_event[:created_at]).to eq time
    end

    it 'defaults to now() when no created_at timestamp is supplied' do
      event_store.sink(new_event(aggregate_id: aggregate_id,
                                 type: :billing_details_provided,
                                 body: { my_event: 'data' }))
      expect(last_event[:created_at]).to be_instance_of(Time)
    end
  end
end
