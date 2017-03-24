RSpec.describe EventSourcery::EventStore::SignalHandlingSubscriptionMaster do
  subject(:subscription_master) { described_class.new }

  describe 'shutdown_if_requested' do
    subject(:shutdown_if_requested) { subscription_master.shutdown_if_requested }

    before do
      allow(Signal).to receive(:trap)
    end

    %i(TERM INT).each do |signal|
      context "after receiving a #{signal} signal" do
        before do
          allow(Signal).to receive(:trap).with(signal).and_yield
        end

        it 'throws :stop' do
          expect { shutdown_if_requested }.to throw_symbol(:stop)
        end
      end
    end

    context 'given no signal has been received' do
      it 'does nothing' do
        shutdown_if_requested
      end
    end
  end
end
