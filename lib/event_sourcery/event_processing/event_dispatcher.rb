module EventSourcery
  module EventProcessing
    # Dispatch events to multiple ESPs
    # Has the weakness of if a new ESP is added it will starve the others until it's caught up
    class EventDispatcher
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
          send_to_processor(event_processor, events)
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

      def send_to_processor(event_processor, events)
        last_processed_event_id = @tracker.last_processed_event_id(event_processor.class.processor_name) || 0
        last_event_id = events.last.id
        events_to_process = events.select { |event| last_processed_event_id < event.id }
        event_processor.send(:process_events, events_to_process) if !events_to_process.empty?
        @on_events_processed.call(event_processor.class.processor_name, last_event_id)
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
