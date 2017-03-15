module EventSourcery
  module EventStore
    class SubscriptionMaster
      def initialize
        @shutdown_requested = false
      end

      def shutdown_if_requested
        throw :stop if @shutdown_requested
      end

      def request_shutdown
        @shutdown_requested = true
      end
    end
  end
end
