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
        # Handler that processes the given event.
        #
        # @raise [EventProcessingError] error raised due to processing isssues
        # @raise [UnableToProcessEventError] raised if unable to process event type
        #
        # @param event [Event] the event to process
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
        rescue
          raise EventProcessingError.new(event: event, processor: self)
        end
      end

      module ClassMethods

        # @attr_reader processes_event_types [Array] Process Event Types
        # @attr_reader event_handlers [Hash] Hash of handler blocks keyed by event
        attr_reader :processes_event_types, :event_handlers

        # Registers the event types to process.
        #
        # @param event_types a collection of event types to process
        def processes_events(*event_types)
          @processes_event_types = Array(@processes_event_types) | event_types.map(&:to_s)
        end

        # Indicate that this class can process all event types. Note that you need to call this method if you
        # intend to process all event types, without calling {ProcessHandler#process} for each event type.
        def processes_all_events
          define_singleton_method :processes? do |_|
            true
          end
        end

        # Can this class process this event type.
        # If you use process_all_events this will always return true
        #
        # @param event_type the event type to check
        #
        # @return [True, False]
        def processes?(event_type)
          processes_event_types &&
            processes_event_types.include?(event_type.to_s)
        end

        # Set the name of the processor.
        # Returns the class name if no name is given.
        #
        # @param name [String] the name of the processor to set
        def processor_name(name = nil)
          if name
            @processor_name = name
          else
            (defined?(@processor_name) && @processor_name) || self.name
          end
        end

        # Process the events for the given event types with the given block.
        #
        # @param event_classes the event type classes to process
        # @param block the code block used to process
        def process(*event_classes, &block)
          event_classes.each do |event_class|
            processes_events event_class.type
            @event_handlers[event_class.type] << block
          end
        end
      end

      # Calls processes_event_types method on the instance class
      def processes_event_types
        self.class.processes_event_types
      end

      # Set up the event tracker
      def setup
        tracker.setup(processor_name)
      end

      # Reset the event tracker
      def reset
        tracker.reset_last_processed_event_id(processor_name)
      end

      # Return the last processed event id
      #
      # @return [Int] the id of the last processed event
      def last_processed_event_id
        tracker.last_processed_event_id(processor_name)
      end

      # Calls processor_name method on the instance class
      def processor_name
        self.class.processor_name
      end

      # Calls processes? method on the instance class
      def processes?(event_type)
        self.class.processes?(event_type)
      end

      # Subscribe to the given event source.
      #
      # @param event_source the event source to subscribe to
      # @param subscription_master [SignalHandlingSubscriptionMaster]
      def subscribe_to(event_source, subscription_master: EventStore::SignalHandlingSubscriptionMaster.new)
        setup
        event_source.subscribe(from_id: last_processed_event_id + 1,
                              event_types: processes_event_types,
                              subscription_master: subscription_master) do |events|
          process_events(events, subscription_master)
        end
      end

      # @attr_writer tracker the tracker for the class
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
