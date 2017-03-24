module EventSourcery
  module EventStore
    class SignalHandlingSubscriptionMaster
      def initialize
        @shutdown_requested = false
        setup_graceful_shutdown
      end

      def shutdown_if_requested
        throw :stop if @shutdown_requested
      end

      private

      def setup_graceful_shutdown
        %i(TERM INT).each do |signal|
          Signal.trap(signal) { @shutdown_requested = true }
        end
      end
    end
  end
end
