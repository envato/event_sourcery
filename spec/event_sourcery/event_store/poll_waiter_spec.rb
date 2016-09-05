RSpec.describe EventSourcery::EventStore::PollWaiter do
  subject(:poll_waiter) { described_class.new(interval: 0) }

  it 'calls the block and sleeps' do
    count = 0
    poll_waiter.poll do
      count += 1
      throw :stop if count == 3
    end
    expect(count).to eq 3
  end
end
