module EventSourcery
  module EventStore
    class PollWaiter
      def initialize(interval: 0.5)
        @interval = interval
      end

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
