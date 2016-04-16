module Fountainhead
  module ProcessedEventTrackerAdapters
    class Memory
      def initialize
        @state = Hash.new(0)
      end

      def setup(processor_name)
        @state[processor_name] = 0
      end

      def processed_event(processor_name, event_id)
        @state[processor_name.to_s] = event_id
      end

      def processing_event(processor_name, event_id)
        yield
        processed_event(processor_name, event_id)
      end

      def reset_last_processed_event_id(processor_name)
        @state[processor_name.to_s] = 0
      end

      def last_processed_event_id(processor_name)
        @state.fetch(processor_name.to_s, 0)
      end

      def tracked_processors
        @state.keys
      end
    end
  end
end
