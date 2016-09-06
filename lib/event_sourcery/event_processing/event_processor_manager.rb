module EventSourcery
  module EventProcessing
    # Responsible for sending events to processors and tracking position in the stream
    class EventProcessorManager
      def initialize(tracker:, event_processors:, event_store:)
        @tracker = tracker
        @event_processors = event_processors
        @event_store = event_store
        @on_events_processed = proc { }
      end

      def on_events_processed(&block)
        @on_events_processed = block
      end

      def process_events(events)
        @event_processors.each do |event_processor|
          track_and_send_to_processor(event_processor, events)
        end
      end

      def start!(after_listen: nil)
        setup_processors_and_trackers
        @event_store.subscribe(from_id: lowest_event_id, event_types: combined_event_types, after_listen: after_listen) do |events|
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
        last_event_id = events.last.id
        if event_processor.class.batch_processing_enabled?
          process_in_batches(event_processor, events, last_processed_event_id, last_event_id)
        else
          process_one_by_one(event_processor, events, last_processed_event_id)
        end
        @on_events_processed.call(event_processor.class.processor_name, last_event_id)
      end

      def process_in_batches(event_processor, events, last_processed_event_id, last_event_id)
        @tracker.processing_event(event_processor.class.processor_name, last_event_id) do
          events.each do |event|
            process_event(event_processor, event, last_processed_event_id)
          end
        end
      end

      def process_one_by_one(event_processor, events, last_processed_event_id)
        events.each do |event|
          @tracker.processing_event(event_processor.class.processor_name, event.id) do
            process_event(event_processor, event, last_processed_event_id)
          end
        end
      end

      def process_event(event_processor, event, last_processed_event_id)
        if last_processed_event_id < event.id
          event_processor.process(event)
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
