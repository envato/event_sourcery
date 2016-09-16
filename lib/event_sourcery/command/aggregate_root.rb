module EventSourcery
  module Command
    module AggregateRoot
      UnknownEventError = Class.new(RuntimeError)

      def initialize(id, event_sink, on_unknown_event: EventSourcery.config.on_unknown_event)
        @id = id
        @event_sink = event_sink
        @current_version = 0
        @on_unknown_event = on_unknown_event
      end

      def load_history(events)
        events.each do |event|
          apply_event(event)
          @current_version = event.version
        end
      end

      private

      attr_reader :id, :event_sink

      def apply_event(event)
        mutate_state_from(event)
        unless event.persisted?
          event_with_aggregate_id = Event.new(aggregate_id: @id,
                                              type: event.type,
                                              body: event.body)
          event_sink.sink(event_with_aggregate_id, expected_version: @current_version)
          @current_version += 1
        end
      end

      def mutate_state_from(event)
        method_name = "apply_#{event.type}"

        if respond_to?(method_name, true)
          send(method_name, event)
        else
          @on_unknown_event.call(event)
        end
      end
    end
  end
end
