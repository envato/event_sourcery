module EventSourcery
  module EventStore

    # This class provides a basic poll waiter implementation that calls the provided block and sleeps for the specified interval, to be used by a {Subscription}.
    class PollWaiter
      #
      # @param interval [Float] Optional. Will default to `0.5`
      def initialize(interval: 0.5)
        @interval = interval
      end

      # Start polling. Call the provided block and sleep. Repeat until `:stop` is thrown (usually via a subscription master).
      #
      # @param block [Proc] code block to be called when polling
      #
      # @see SignalHandlingSubscriptionMaster
      # @see Subscription
      def poll(&block)
        catch(:stop) do
          loop do
            block.call
            sleep @interval
          end
        end
      end
    end
  end
end
