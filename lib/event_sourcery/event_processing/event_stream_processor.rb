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
          @all_event_handler = nil
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
        #
        # @param event [Event] the event to process
        def process(event)
          @_event = event
          handlers = (self.class.event_handlers[event.type] + [self.class.all_event_handler]).compact
          handlers.each do |handler|
            instance_exec(event, &handler)
          end
          @_event = nil
        rescue => error
          report_error(error, event)
          raise EventProcessingError.new(event: event, processor: self)
        end
      end

      module ClassMethods

        # @attr_reader processes_event_types [Array] Process Event Types
        # @attr_reader event_handlers [Hash] Hash of handler blocks keyed by event
        # @attr_reader all_event_handler [Proc] An event handler
        attr_reader :processes_event_types, :event_handlers, :all_event_handler

        # Can this class process this event type.
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
        # @raise [MultipleCatchAllHandlersDefined] error raised when attempting to define multiple catch all handlers.
        #
        # @param event_classes the event type classes to process
        # @param block the code block used to process
        def process(*event_classes, &block)
          if event_classes.empty?
            if @all_event_handler
              raise MultipleCatchAllHandlersDefined, 'Attemping to define multiple catch all event handlers.'
            else
              @all_event_handler = block
            end
          else
            @processes_event_types ||= []
            event_classes.each do |event_class|
              @processes_event_types << event_class.type
              @event_handlers[event_class.type] << block
            end
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

      def report_error(error, event)
        EventSourcery.config.on_event_processor_error.call(error, event, self)
      end
    end
  end
end
