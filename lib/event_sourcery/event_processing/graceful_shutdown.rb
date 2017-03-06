module EventSourcery
  module EventProcessing
    class GracefulShutdown
      def initialize
        @shutdown_requested = false
      end

      def mark_safe_shutdown_point
        throw :stop if @shutdown_requested
      end

      def shutdown_when_safe
        @shutdown_requested = true
      end
    end
  end
end
