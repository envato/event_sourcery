class TestPoller
  def initialize(times = 1)
    @times = times
  end

  def poll(*args, &block)
    Array(@times).each do
      yield
    end
  end
end

RSpec.describe EventSourcery::EventStore::Postgres::Subscription do
  def on_new_events_callback(events)
    @events = events
    throw :stop
  end

  let(:event_types) { [] }
  let(:event_store) { EventSourcery::EventStore::Postgres::Connection.new(pg_connection) }
  subject(:subscription) { described_class.new(event_store: event_store,
                                               poll_waiter: TestPoller.new,
                                               event_types: event_types,
                                               from_event_id: 1,
                                               on_new_events: method(:on_new_events_callback)) }

  let(:waiter) { TestPoller.new }

  it 'yields new events' do
    event_store.sink(new_event)
    subscription.start
    expect(@events.map(&:id)).to eq [1]
  end

  it 'yields new events in batches' do
    event_store.sink(new_event)
    event_store.sink(new_event)
    subscription.start
    expect(@events.map(&:id)).to eq [1, 2]
  end
end
