module ESFramework
  module DownstreamEventProcessor
    UndeclaredEventEmissionError = Class.new(StandardError)

    def self.included(base)
      base.include(EventProcessor)
      base.extend(ClassMethods)
      base.prepend(TableOwner)
      base.prepend(ProcessHandler)
      base.prepend(EventProcessorOverrides)
    end

    module ClassMethods
      def emits_events(*event_types)
        @emits_event_types = event_types.map(&:to_s)
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

    module EventProcessorOverrides
      def setup
        if event_source
          @latest_event_id_on_setup = event_source.latest_event_id
        end
        super
      end
    end

    def initialize(tracker:, db_connection: nil, event_source: nil, event_sink: nil)
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

    DRIVEN_BY_EVENT_PAYLOAD_KEY = :_driven_by_event_id

    module ProcessHandler
      def process(event)
        @event = event
        if self.class.emits_events? && clutch_down?
          keep_track_of_previously_emitted_events
        end
        if self.class.processes?(event.type)
          super(event)
        end
        if clutch_down? && event_is_latest_event_on_setup?
          release_clutch
        end
        tracker.processed_event(self.class.processor_name, event.id)
        @event = nil
      end
    end

    def last_processed_event_id
      tracker.last_processed_event_id(self.class.processor_name)
    end

    private

    attr_reader :event_sink, :event_source, :event, :latest_event_id_on_setup

    def clutch_down?
      false
    end

    def release_clutch
      return if events_to_emit.empty?
      begin
        event_id, (event_args, action) = events_to_emit.shift
        invoke_action_and_emit_event(event_args.fetch(:aggregate_id), event_args.fetch(:type), event_args.fetch(:body), action)
      end while events_to_emit.length != 0
    end

    def emit_event(aggregate_id:, type:, body: {}, &block)
      raise UndeclaredEventEmissionError unless self.class.emits_event?(type)
      body = body.merge(DRIVEN_BY_EVENT_PAYLOAD_KEY => event.id)
      if clutch_down?
        events_to_emit[event.id] = [{ aggregate_id: aggregate_id, type: type, body: body }, block]
      else
        invoke_action_and_emit_event(aggregate_id, type, body, block)
      end
    end

    def invoke_action_and_emit_event(aggregate_id, type, body, action)
      action.call(body) if action
      event_sink.sink(aggregate_id: aggregate_id, type: type, body: body)
    end

    def keep_track_of_previously_emitted_events
      if self.class.emit_events.include?(event.type)
        events_to_emit.delete(event.body[DRIVEN_BY_EVENT_PAYLOAD_KEY])
      end
    end

    def events_to_emit
      @events_to_emit ||= {}
    end

    def event_is_latest_event_on_setup?
      latest_event_id_on_setup == event.id
    end
  end
end
