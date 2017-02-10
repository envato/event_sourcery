module EventSourcery
  module EventStore
    class EventBuilder
      def initialize(event_base_class:)
        @event_base_class = event_base_class
      end

      def build(event_data)
        type = event_data.fetch(:type)
        klass = event_base_class.resolve_type(type)
        klass.new(event_data)
      end

      private

      attr_reader :event_base_class
    end
  end
end
