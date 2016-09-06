module EventSourcery
  module EventProcessing
    # Better name?
    class EventProcessorManager
      def initialize(tracker:, event_processors:, event_store:)
        @tracker = tracker
        @event_processors = event_processors
        @event_store = event_store
      end

      def start!
        setup_trackers
        @event_store.subscribe(from_id: lowest_event_id, event_types: combined_event_types) do |events|
          @event_processors.each do |event_processor|
            process_events(event_processor, events)
          end
        end
      end

      private

      def process_events(event_processor, events)
        last_processed_event_id = tracker.last_processed_event_id(event_processor.class.processor_name) || 0
        tracker.processing_event(events.last.id) do
          events.each do |event|
            if last_processed_event_id < event.id
              event_processor.process(event)
            end
          end
        end
      end

      def lowest_event_id
        @event_processors.map do |event_processor|
          tracker.last_processed_event_id(event_processor.class.processor_name) || 0
        end.sort.first
      end

      def combined_event_types
        @event_processor.flat_map do |event_processor|
          event_processor.event_types
        end.uniq
      end

      def setup_trackers
        @event_processor.each do |event_processor|
          tracker.setup(event_processor.class.processor_name)
        end
      end
    end
  end
end
