RSpec.describe EventSourcery::EventStore::SubscriptionMaster do
  subject(:subscription_master) { described_class.new }

  describe 'shutdown_if_requested' do
    subject(:shutdown_if_requested) { subscription_master.shutdown_if_requested }

    context 'given shutdown_when_safe requested' do
      before do
        subscription_master.request_shutdown
      end

      it 'throws :stop' do
        expect { shutdown_if_requested }.to throw_symbol(:stop)
      end
    end

    context 'given shutdown_when_safe has not been requested' do
      it 'does nothing' do
        shutdown_if_requested
      end
    end
  end
end
