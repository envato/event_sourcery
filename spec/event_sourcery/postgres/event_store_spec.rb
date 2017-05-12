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
end
