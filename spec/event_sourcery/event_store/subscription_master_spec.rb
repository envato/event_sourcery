RSpec.describe EventSourcery::EventStore::SubscriptionMaster do
  subject(:subscription_master) { described_class.new }

  describe 'mark_safe_shutdown_point' do
    subject(:mark_safe_shutdown_point) { subscription_master.mark_safe_shutdown_point }

    context 'given shutdown_when_safe requested' do
      before do
        subscription_master.request_shutdown
      end

      it 'throws :stop' do
        expect { mark_safe_shutdown_point }.to throw_symbol(:stop)
      end
    end

    context 'given shutdown_when_safe has not been requested' do
      it 'does nothing' do
        mark_safe_shutdown_point
      end
    end
  end
end
