module EventSourcery
  module Postgres
    module Reactor
      UndeclaredEventEmissionError = Class.new(StandardError)

      def self.included(base)
        base.include(EventProcessing::EventStreamProcessor)
        base.extend(ClassMethods)
        base.prepend(TableOwner)
        base.include(InstanceMethods)
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
      CAUSATION_ID_METADATA_KEY = :causation_id
      REACTOR_NAME_METADATA_KEY = :reactor_name

      private

      attr_reader :event_sink, :event_source

      def emit_event(event_or_hash, &block)
        event = if Event === event_or_hash
          event_or_hash
        else
          Event.new(event_or_hash)
        end
        raise UndeclaredEventEmissionError unless self.class.emits_event?(event.type)
        event.body.merge!(DRIVEN_BY_EVENT_PAYLOAD_KEY => _event.id)
        event.metadata.merge!(
          CAUSATION_ID_METADATA_KEY => _event.id,
          REACTOR_NAME_METADATA_KEY => self.processor_name,
        )
        if already_actioned?
          EventSourcery.logger.debug { "[#{self.processor_name}] Already actioned event: #{event.inspect}. Skipping." }
        else
          invoke_action_and_emit_event(event, block)
          tracker.actioned_event(processor_name, _event.id)
          EventSourcery.logger.debug { "[#{self.processor_name}] Emitted event: #{event.inspect}" }
        end
      end

      def already_actioned?
        last_processed_event_id < last_actioned_event_id
      end

      def invoke_action_and_emit_event(event, action)
        action.call(event.body) if action
        event_sink.sink(event)
      end

      def last_actioned_event_id
        tracker.last_actioned_event_id(processor_name)
      end
    end
  end
end
