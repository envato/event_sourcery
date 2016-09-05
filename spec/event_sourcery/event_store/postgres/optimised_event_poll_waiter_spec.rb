RSpec.describe EventSourcery::EventStore::Postgres::OptimisedEventPollWaiter do
  let(:after_listen) { proc { } }
  subject(:waiter) { described_class.new(pg_connection: pg_connection, after_listen: after_listen) }

  def notify_event_ids(*ids)
    ids.each do |id|
      pg_connection.notify('new_event', payload: id)
    end
  end

  it 'does an initial call' do
    waiter.poll(after_listen: proc { }) do
      @called = true
      throw :stop
    end

    expect(@called).to eq true
  end

  it 'calls on new event' do
    waiter.poll(after_listen: proc { notify_event_ids(1) }) do
      @called = true
      throw :stop
    end

    expect(@called).to eq true
  end

  it 'calls once when multiple events are in the queue' do
    waiter.poll(after_listen: proc { notify_event_ids(1, 2) }) do
      @called = true
      throw :stop
    end

    expect(@called).to eq true
  end
end
