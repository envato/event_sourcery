require 'forwardable'

module EventSourcery
  module EventStore
    class EventSink
      def initialize(event_store)
        @event_store = event_store
      end

      def sink(event_or_events, expected_version: nil)
        events = Array(event_or_events)
        events.each do |event|
          raise(InvalidEventError, "#{event.class} not valid: #{event.validation_errors.values.join(', ')}") unless event.valid?
        end
        event_store.sink(events, expected_version: expected_version)
      end

      private

      attr_reader :event_store
    end
  end
end
