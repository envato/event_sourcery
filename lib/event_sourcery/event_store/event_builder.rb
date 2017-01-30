module EventSourcery
  module EventStore
    class EventBuilder

      def initialize(event_type_serializer:)
        @event_type_serializer = event_type_serializer
      end

      def build(event_data)
        @event_type_serializer.deserialize(event_data[:type]).new(event_data)
      end
    end
  end
end
