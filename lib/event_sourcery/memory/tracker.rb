module EventSourcery
  module Memory
    class Tracker
      def initialize
        @state = Hash.new(0)
      end

      def setup(processor_name)
        @state[processor_name.to_s] = 0
      end

      def processed_event(processor_name, event_id)
        @state[processor_name.to_s] = event_id
      end

      alias :reset_last_processed_event_id :setup

      def last_processed_event_id(processor_name)
        @state[processor_name.to_s]
      end

      def tracked_processors
        @state.keys
      end
    end
  end
end
