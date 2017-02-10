module EventSourcery
  module EventStore
    class EventBuilder
      def initialize(event_class_resolver:, upcaster:)
        @event_class_resolver = event_class_resolver
        @upcaster = upcaster
      end

      def build(event_data)
        type = event_data.fetch(:type)
        event_class = event_class_resolver.resolve(type)
        upcasted_body = upcaster.upcast(type, event_data.fetch(:body))
        event_class.new(event_data.merge(body: upcasted_body))
      end

      private

      attr_reader :event_class_resolver, :upcaster
    end
  end
end
