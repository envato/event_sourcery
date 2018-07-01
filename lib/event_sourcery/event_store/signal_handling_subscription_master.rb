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
          Signal.trap(signal) do
            @shutdown_requested = true
            wakeup_main_thread
          end
        end
      end

      # If the main thread happens to be sleeping when we receive the
      # interrupt, wake it up.
      #
      # Note: the main thread processes the signal trap, hence calling
      # Thread.main.wakeup in the signal trap is a no-op as it's undoubtedly
      # awake. Instead, we need to fork a new thread, which waits for the main
      # thread to go back to sleep and then wakes it up.
      def wakeup_main_thread
        Thread.fork do
          main_thread = Thread.main
          10.times do
            if main_thread.status == 'sleep'
              main_thread.wakeup
              break
            end
            sleep 0.01
          end
        end
      end
    end
  end
end
