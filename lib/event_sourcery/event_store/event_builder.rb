module EventSourcery
  module EventStore
    class EventBuilder
      def initialize(event_base_class:, upcaster:)
        @event_base_class = event_base_class
        @upcaster = upcaster
      end

      def build(event_data)
        type = event_data.fetch(:type)
        klass = event_base_class.resolve_type(type)
        upcasted_body = upcaster.upcast(type, event_data.fetch(:body))
        klass.new(event_data.merge(body: upcasted_body))
      end

      private

      attr_reader :event_base_class, :upcaster
    end
  end
end
