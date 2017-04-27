module EventSourcery
  module EventProcessing
    module Reactor
      UndeclaredEventEmissionError = Class.new(StandardError)

      def self.included(base)
        base.include(EventStreamProcessor)
        base.extend(ClassMethods)
        base.prepend(ProcessHandler)
        base.prepend(TableOwner)
        base.include(InstanceMethods)
      end

      module ProcessHandler
        def process(event)
          @_event = event

          if self.class.emits_events? && clutch_down?
            keep_track_of_previously_emitted_events
          end

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

          if clutch_down? && event_is_latest_event_on_setup?
            release_clutch
          end

          @_event = nil
        end

        def setup
          super

          if event_source
            @latest_event_id_on_setup = event_source.latest_event_id
          end
        end

        def event_is_latest_event_on_setup?
          latest_event_id_on_setup == _event.id
        end

        def release_clutch
          return if events_to_emit.empty?
          begin
            event_id, (event, action) = events_to_emit.shift
            invoke_action_and_emit_event(event, action)
          end while events_to_emit.length != 0
        end

        def keep_track_of_previously_emitted_events
          if self.class.emit_events.include?(_event.type)
            events_to_emit.delete(_event.body[DRIVEN_BY_EVENT_PAYLOAD_KEY])
          end
        end

        attr_reader :latest_event_id_on_setup
      end

      module ClassMethods
        def emits_events(*event_types)
          @emits_event_types = event_types.map(&:to_s)

          @emits_event_types.each do |event_type|
            define_method "emit_#{event_type}" do |aggregate_id, body|
              emit_event(
                type: event_type,
                aggregate_id: aggregate_id,
                body: body
              )
            end
          end
        end

        def emit_events
          @emits_event_types ||= []
        end

        def emits_events?
          !emit_events.empty?
        end

        def emits_event?(event_type)
          emit_events.include?(event_type.to_s)
        end
      end

      module InstanceMethods
        def initialize(tracker: EventSourcery.config.event_tracker, db_connection: EventSourcery.config.projections_database, event_source: EventSourcery.config.event_source, event_sink: EventSourcery.config.event_sink)
          @tracker = tracker
          @event_source = event_source
          @event_sink = event_sink
          @db_connection = db_connection
          if self.class.emits_events?
            if event_sink.nil? || event_source.nil?
              raise ArgumentError, 'An event sink and source is required for processors that emit events'
            end
          end
        end
      end

      DRIVEN_BY_EVENT_PAYLOAD_KEY = :_driven_by_event_id

      private

      attr_reader :event_sink, :event_source

      def clutch_down?
        false
      end

      def events_to_emit
        @events_to_emit ||= {}
      end

      def emit_event(event_or_hash, &block)
        event = if Event === event_or_hash
          event_or_hash
        else
          Event.new(event_or_hash)
        end
        raise UndeclaredEventEmissionError unless self.class.emits_event?(event.type)
        event.body.merge!(DRIVEN_BY_EVENT_PAYLOAD_KEY => _event.id)

        if clutch_down?
          events_to_emit[event.id] = [event, block]
          EventSourcery.logger.debug { "[#{self.processor_name}] Stored event: #{event.inspect}" }
        else
          invoke_action_and_emit_event(event, block)
          EventSourcery.logger.debug { "[#{self.processor_name}] Emitted event: #{event.inspect}" }
        end
      end

      def invoke_action_and_emit_event(event, action)
        action.call(event.body) if action
        event_sink.sink(event)
      end
    end
  end
end
