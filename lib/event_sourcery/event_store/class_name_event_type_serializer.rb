module EventSourcery
  module EventStore
    class ClassNameEventTypeSerializer
      def serialize(event)
        event.class.name
      end

      def deserialize(event_type)
        Object.const_get(event_type)
      end
    end
  end
end
