module EventSourcery
  module Utils
    class QueueWithIntervalCallback < ::Queue
      attr_accessor :interval_callback

      def initialize(interval_callback: proc { }, interval: 1, poll_interval: 0.1)
        @interval_callback = interval_callback
        @interval = interval
        @poll_interval = poll_interval
        super()
      end

      def pop(non_block_without_callback = false)
        return super if non_block_without_callback
        pop_with_interval_callback
      end

      private

      def pop_with_interval_callback
        time = Time.now
        loop do
          return pop(true) if !empty?
          if Time.now > time + @interval
            @interval_callback.call
            time = Time.now
          end
          sleep @poll_interval
        end
      end
    end
  end
end
