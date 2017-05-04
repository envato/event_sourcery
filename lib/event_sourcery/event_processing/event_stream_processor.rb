module EventSourcery
  module EventProcessing
    module EventStreamProcessor
      def self.included(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
        base.prepend(ProcessHandler)
        EventSourcery.event_stream_processor_registry.register(base)
        base.class_eval do
          @event_handlers = Hash.new { |hash, key| hash[key] = [] }
        end
      end

      module InstanceMethods
        def initialize(tracker:)
          @tracker = tracker
        end
      end

      module ProcessHandler
        def process(event)
          @_event = event
          handlers = self.class.event_handlers[event.type]
          if handlers.any?
            handlers.each do |handler|
              instance_exec(event, &handler)
            end
          elsif self.class.processes?(event.type)
            if defined?(super)
              super(event)
            else
              raise UnableToProcessEventError, "I don't know how to process '#{event.type}' events."
            end
          end
          @_event = nil
        rescue => error
          raise EventProcessingError.new(event, error)
        end
      end

      module ClassMethods
        attr_reader :processes_event_types, :event_handlers

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

        def process(*event_classes, &block)
          event_classes.each do |event_class|
            processes_events event_class.type
            @event_handlers[event_class.type] << block
          end
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

      def subscribe_to(event_store, subscription_master: EventStore::SignalHandlingSubscriptionMaster.new)
        setup
        event_store.subscribe(from_id: last_processed_event_id + 1,
                              event_types: processes_event_types,
                              subscription_master: subscription_master) do |events|
          process_events(events, subscription_master)
        end
      end

      attr_accessor :tracker

      private

      attr_reader :_event

      def process_events(events, subscription_master)
        events.each do |event|
          subscription_master.shutdown_if_requested
          process(event)
          tracker.processed_event(processor_name, event.id)
          EventSourcery.logger.debug { "[#{processor_name}] Processed event: #{event.inspect}" }
        end
        EventSourcery.logger.info { "[#{processor_name}] Processed up to event id: #{events.last.id}" }
      end
    end
  end
end
