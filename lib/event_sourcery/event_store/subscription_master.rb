module EventSourcery
  module EventStore
    class SubscriptionMaster
      def initialize
        @shutdown_requested = false
      end

      def mark_safe_shutdown_point
        throw :stop if @shutdown_requested
      end

      def request_shutdown
        @shutdown_requested = true
      end
    end
  end
end
