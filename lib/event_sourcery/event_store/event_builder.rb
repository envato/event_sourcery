module EventSourcery
  module EventStore
    class EventBuilder
      def initialize(event_type_serializer:)
        @event_type_serializer = event_type_serializer
      end

      def build(**event_data)
        type = event_data.fetch(:type)
        klass = event_type_serializer.deserialize(type)
        upcast(klass.new(**event_data))
      end

      private

      attr_reader :event_type_serializer

      def upcast(event)
        event.class.upcast(event)
      end
    end
  end
end
