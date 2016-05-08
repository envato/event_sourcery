module EventSourcery
  module EventProcessor
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def processes_event_types
        @processes_event_types ||= []
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

      def processor_name=(name)
        @processor_name = name
      end

      def processor_name
        @processor_name || self.name
      end
    end

    def setup
      tracker.setup(self.class.processor_name)
    end

    def reset
      tracker.reset_last_processed_event_id(self.class.processor_name)
    end

    def last_processed_event_id
      tracker.last_processed_event_id(self.class.processor_name)
    end

    def subscribe_to(feeder)
      feeder.subscribe(last_processed_event_id, event_types: self.class.processes_event_types) do |event|
        process(event)
      end
    end

    private

    attr_reader :tracker
  end
end
