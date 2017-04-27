RSpec.describe EventSourcery::EventStore::Postgres::OptimisedEventPollWaiter do
  let(:after_listen) { proc { } }
  subject(:waiter) { described_class.new(pg_connection: pg_connection, after_listen: after_listen) }

  before do
    allow(EventSourcery::Utils::QueueWithIntervalCallback).to receive(:new)
      .and_return(EventSourcery::Utils::QueueWithIntervalCallback.new(callback_interval: 0))
  end

  after do
    waiter.shutdown!
  end

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

  context 'when the listening thread dies' do
    before do
      allow(pg_connection).to receive(:listen).and_raise(StandardError)
    end

    it 'raise an error' do
      expect {
        waiter.poll { }
      }.to raise_error(described_class::ListenThreadDied)
    end
  end
end
