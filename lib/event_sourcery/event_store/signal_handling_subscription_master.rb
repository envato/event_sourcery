module EventSourcery
  module EventStore
    # Manages shutdown signals and facilitate graceful shutdowns of subscriptions.
    #
    # @see Subscription
    class SignalHandlingSubscriptionMaster
      def initialize
        @shutdown_requested = false
        setup_graceful_shutdown
      end

      # If a shutdown has been requested through a `TERM` or `INT` signal, this will throw a `:stop`
      # (generally) causing a Subscription to stop listening for events.
      #
      # @see Subscription#start
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
