RSpec.describe EventSourcery::EventProcessing::GracefulShutdown do
  subject(:graceful_shutdown) { described_class.new }

  describe 'mark_safe_shutdown_point' do
    subject(:mark_safe_shutdown_point) { graceful_shutdown.mark_safe_shutdown_point }

    context 'given shutdown_when_safe requested' do
      before do
        graceful_shutdown.shutdown_when_safe
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
