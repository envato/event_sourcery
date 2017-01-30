module EventSourcery
  module EventStore
    class GenericEventTypeSerializer
      def serialize(event)
        event.type
      end

      def deserialize(event_type)
        Event
      end
    end
  end
end
