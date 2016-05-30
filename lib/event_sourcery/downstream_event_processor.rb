module EventSourcery
  module DownstreamEventProcessor
    UndeclaredEventEmissionError = Class.new(StandardError)

    def self.included(base)
      base.include(EventHandler)
      base.extend(ClassMethods)
      base.prepend(TableOwner)
      base.prepend(HandleMethod)
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

    def initialize(db_connection: nil, event_source: nil, event_sink: nil)
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

    module HandleMethod
      def handle(event)
        @event = event
        if self.class.handles?(event.type)
          super(event)
        end
        @event = nil
      end
    end

    private

    attr_reader :event_sink, :event_source, :event, :latest_event_id_on_setup

    def emit_event(aggregate_id:, type:, body: {}, &block)
      raise UndeclaredEventEmissionError unless self.class.emits_event?(type)
      body = body.merge(DRIVEN_BY_EVENT_PAYLOAD_KEY => event.id)
      invoke_action_and_emit_event(aggregate_id, type, body, block)
    end

    def invoke_action_and_emit_event(aggregate_id, type, body, action)
      action.call(body) if action
      event_sink.sink(aggregate_id: aggregate_id, type: type, body: body)
    end
  end
end
