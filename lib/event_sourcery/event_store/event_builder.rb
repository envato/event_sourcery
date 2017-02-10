module EventSourcery
  module EventStore
    class EventBuilder
      def initialize(event_class_resolver:)
        @event_class_resolver = event_class_resolver
      end

      def build(event_data)
        @event_class_resolver.resolve(event_data.fetch(:type)).new(event_data)
      end

      private

      attr_reader :event_class_resolver
    end
  end
end
