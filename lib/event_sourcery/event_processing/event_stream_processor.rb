module EventSourcery
  module EventProcessing
    module EventStreamProcessor
      def self.included(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
      end

      module InstanceMethods
        def initialize(tracker:)
          @tracker = tracker
        end
      end

      module ClassMethods
        def processes_event_types
          @processes_event_types
        end

        def processes_events(*event_types)
          @processes_event_types = event_types.map(&:to_s)
        end

        def processes_all_events
          define_singleton_method :processes? do |_|
            true
          end
        end

        def processes?(event_type)
          processes_event_types.include?(event_type.to_s)
        end

        def processor_name(name = nil)
          if name
            @processor_name = name
          else
            @processor_name || self.name
          end
        end
      end

      def setup
        tracker.setup(processor_name)
      end

      def reset
        tracker.reset_last_processed_event_id(processor_name)
      end

      def last_processed_event_id
        tracker.last_processed_event_id(processor_name)
      end

      def processor_name
        self.class.processor_name
      end

      def processes?(event_type)
        self.class.processes?(event_type)
      end

      def subscribe_to(event_store)
        setup
        event_store.subscribe(from_id: last_processed_event_id + 1,
                              event_types: self.class.processes_event_types) do |events|
          process_events(events)
        end
      end

      attr_accessor :tracker

      private

      def process_events(events)
        events.each do |event|
          process(event)
        end
      end
    end
  end
end
