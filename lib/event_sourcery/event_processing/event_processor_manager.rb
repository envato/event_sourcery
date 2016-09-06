module EventSourcery
  module EventProcessing
    # Responsible for sending events to processors and tracking position in the stream
    class EventProcessorManager
      def initialize(tracker:, event_processors:, event_store:)
        @tracker = tracker
        @event_processors = event_processors
        @event_store = event_store
      end

      def process_events(events)
        @event_processors.each do |event_processor|
          track_and_send_to_processor(event_processor, events)
        end
      end

      def start!(after_listen: nil)
        setup_processors_and_trackers
        @event_store.subscribe(from_id: lowest_event_id, event_types: combined_event_types, after_listen: after_listen) do |events|
          puts events.inspect
          process_events(events)
        end
      end

      def setup_processors_and_trackers
        @event_processors.each do |event_processor|
          @tracker.setup(event_processor.class.processor_name)
          event_processor.setup
        end
      end

      private

      def track_and_send_to_processor(event_processor, events)
        last_processed_event_id = @tracker.last_processed_event_id(event_processor.class.processor_name) || 0
        @tracker.processing_event(event_processor.class.processor_name, events.last.id) do
          events.each do |event|
            if last_processed_event_id < event.id
              event_processor.process(event)
            end
          end
        end
      end

      def lowest_event_id
        @event_processors.map do |event_processor|
          @tracker.last_processed_event_id(event_processor.class.processor_name) || 0
        end.sort.first
      end

      def combined_event_types
        event_types = @event_processors.flat_map do |event_processor|
          event_processor.class.processes_event_types
        end.compact.uniq
        if event_types.empty?
          nil
        else
          event_types
        end
      end
    end
  end
end
