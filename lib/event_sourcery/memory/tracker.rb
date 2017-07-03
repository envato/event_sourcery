module EventSourcery
  module Memory
    # Being able to know where you're at when reading an event stream
    # is important. In here are mechanisms to do so.
    class Tracker
      # Tracking where you're in an event stream at via an in memory hash.
      # Note: This is not persisted and is generally used for testing.
      def initialize
        @state = Hash.new(0)
      end

      # Register a new processor to track or
      # reset an existing tracker's last processed event id.
      # Will start from 0.
      #
      # @param processor_name [String] the name of the processor to track
      def setup(processor_name)
        @state[processor_name.to_s] = 0
      end

      # Update the given processor name to the given event id number.
      #
      # @param processor_name [String] the name of the processor to update
      # @param event_id [Int] the number of the event to update
      def processed_event(processor_name, event_id)
        @state[processor_name.to_s] = event_id
      end

      alias :reset_last_processed_event_id :setup

      # Find the last processed event id for a given processor name.
      #
      # @return [Int] the last event id that the given processor has processed
      def last_processed_event_id(processor_name)
        @state[processor_name.to_s]
      end

      # Returns an array of all the processors that are being tracked.
      #
      # @return [Array] an array of names of the tracked processors
      def tracked_processors
        @state.keys
      end
    end
  end
end
