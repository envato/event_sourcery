RSpec.describe EventSourcery::Postgres::EventStore do
  let(:supports_versions) { true }
  subject(:event_store) { described_class.new(pg_connection) }

  include_examples 'an event store'

  describe '#sink' do
    it 'notifies about a new event' do
      event_id = nil
      Timeout.timeout(1) do
        pg_connection.listen('new_event', loop: false, after_listen: proc { add_event }) do |channel, pid, payload|
          event_id = Integer(payload)
        end
      end
    end
  end

  describe '#subscribe' do
    let(:event) { new_event(aggregate_id: aggregate_id) }
    let(:subscription_master) { spy(EventSourcery::EventStore::SignalHandlingSubscriptionMaster) }

    it 'notifies of new events' do
      event_store.subscribe(from_id: 0,
                            after_listen: proc { event_store.sink(event) },
                            subscription_master: subscription_master) do |events|
        @events = events
        throw :stop
      end
      expect(@events.count).to eq 1
      expect(@events.first.aggregate_id).to eq aggregate_id
    end
  end

  context 'aggregates table version' do
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

    context "when the aggregate doesn't exist" do
      context 'and the expected version is correct - 0' do
        it 'saves the event with and sets the aggregate version to version 1' do
          save_event(expected_version: 0)
          expect(aggregate_version).to eq 1
        end
      end

      context 'with no expected version' do
        it 'saves the event with and sets the aggregate version to version 1' do
          save_event
          expect(aggregate_version).to eq 1
        end
      end
    end

    context 'when the aggregate exists' do
      before do
        add_event
      end

      context 'with a correct expected version - 1' do
        it 'saves the event with and sets the aggregate version to version 2' do
          save_event
          expect(aggregate_version).to eq 2
        end
      end

      context 'with no aggregate version' do
        it 'automatically sets the version on the event and aggregate' do
          save_event
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
