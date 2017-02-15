module EventSourcery
  module EventProcessing
    module EventStreamProcessor
      def self.included(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
        base.prepend(ProcessHandler)
        EventSourcery.event_stream_processor_registry.register(base)
        base.class_eval do
          @handlers = Hash.new
        end
      end

      module InstanceMethods
        def initialize(tracker:)
          @tracker = tracker
        end

        private

        def process_method_name
          'process'
        end
      end

      module ProcessHandler
        def process(event)
          @_event = event
          handler = self.class.handlers[event.class]
          if handler
            instance_exec(event, &handler)
          elsif self.class.processes?(event.type)
            handler_method_name = "#{process_method_name}_#{event.type}"
            if respond_to?(handler_method_name)
              send(handler_method_name, event)
            elsif defined?(super)
              super(event)
            else
              raise UnableToProcessEventError, "I don't know how to process '#{event.type}' events. "\
                                               "To process this event implement a method named '#{handler_method_name}'"
            end
          end
          @_event = nil
        end
      end

      module ClassMethods
        attr_reader :processes_event_types, :handlers

        def processes_events(*event_types)
          @processes_event_types = Array(@processes_event_types) | event_types.map(&:to_s)
        end

        def processes_all_events
          define_singleton_method :processes? do |_|
            true
          end
        end

        def processes?(event_type)
          processes_event_types &&
            processes_event_types.include?(event_type.to_s)
        end

        def processor_name(name = nil)
          if name
            @processor_name = name
          else
            (defined?(@processor_name) && @processor_name) || self.name
          end
        end

        def process(event_class, &block)
          @handlers[event_class] = block
        end
      end

      def processes_event_types
        self.class.processes_event_types
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
                              event_types: processes_event_types) do |events|
          process_events(events)
        end
      end

      attr_accessor :tracker

      private

      attr_reader :_event

      def process_events(events)
        events.each do |event|
          process(event)
          tracker.processed_event(processor_name, event.id)
          EventSourcery.logger.debug { "[#{processor_name}] Processed event: #{event.inspect}" }
        end
        EventSourcery.logger.info { "[#{processor_name}] Processed up to event id: #{events.last.id}" }
      end
    end
  end
end
