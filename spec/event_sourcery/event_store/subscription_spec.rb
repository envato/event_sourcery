class TestPoller
  attr_accessor :times, :after_poll_callback

  def initialize(times: 1, after_poll_callback: proc { })
    @times = times
    @after_poll_callback = after_poll_callback
  end

  def poll(*args, &block)
    Array(1..times).each do
      yield
      after_poll_callback.call
    end
  end

  def shutdown!
  end
end

RSpec.describe EventSourcery::EventStore::Subscription do
  def on_new_events_callback(events)
    @event_batches << events
  end

  let(:event_types) { nil }
  let(:event_store) { EventSourcery::EventStore::Postgres::ConnectionWithOptimisticConcurrency.new(pg_connection) }
  subject(:subscription) { described_class.new(event_store: event_store,
                                               poll_waiter: waiter,
                                               event_types: event_types,
                                               from_event_id: 1,
                                               subscription_master: subscription_master,
                                               on_new_events: method(:on_new_events_callback)) }

  let(:waiter) { TestPoller.new }
  let(:subscription_master) { spy(EventSourcery::EventStore::SubscriptionMaster) }

  before do
    @event_batches = []
  end

  it 'yields new events' do
    event_store.sink(new_event)
    subscription.start
    expect(@event_batches.first.map(&:id)).to eq [1]
  end

  it 'yields new events in batches' do
    waiter.times = 2
    waiter.after_poll_callback = proc { event_store.sink(new_event) }
    event_store.sink(new_event)
    event_store.sink(new_event)
    subscription.start
    expect(@event_batches.first.map(&:id)).to eq [1, 2]
  end

  it 'marks a safe point to shutdown' do
    subscription.start
    expect(subscription_master).to have_received(:shutdown_if_requested)
  end

  context 'with event types' do
    let(:event_types) { ['item_added', 'item_removed'] }

    it 'filters by the given event type' do
      event_store.sink(new_event(type: 'item_added'))
      event_store.sink(new_event(type: 'item_removed'))
      event_store.sink(new_event(type: 'item_starred'))
      waiter.times = 2
      waiter.after_poll_callback = proc { event_store.sink(new_event(type: 'item_added')) }
      subscription.start
      expect(@event_batches.count).to eq 2
      expect(@event_batches.first.map(&:type)).to eq ['item_added', 'item_removed']
      expect(@event_batches.last.map(&:type)).to eq ['item_added']
    end
  end

  context 'when an exception occurs during event polling' do
    before do
      allow(waiter).to receive(:poll).and_raise 'event_poll_error'
    end

    it 'tells the poll waiter to shutdown its thread' do
      expect(waiter).to receive(:shutdown!)
      event_store.sink(new_event)
      expect { subscription.start }.to raise_error 'event_poll_error'
    end
  end
end
