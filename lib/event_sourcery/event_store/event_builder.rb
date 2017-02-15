module EventSourcery
  module EventStore
    class EventBuilder
      def initialize(event_type_serializer:, upcaster:)
        @event_type_serializer = event_type_serializer
        @upcaster = upcaster
      end

      def build(event_data)
        type = event_data.fetch(:type)
        klass = event_type_serializer.deserialize(type)
        upcasted_body = upcaster.upcast(type, event_data.fetch(:body))
        klass.new(event_data.merge(body: upcasted_body))
      end

      private

      attr_reader :event_type_serializer, :upcaster
    end
  end
end
