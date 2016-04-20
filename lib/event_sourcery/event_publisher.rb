module EventSourcery
  class EventPublisher
    class Subscriber
      def initialize(last_seen_event_id, &block)
        @last_seen_event_id = last_seen_event_id
        @block = block
      end

      def call(event)
        @block.call(event)
        @last_seen_event_id = event.id
      end

      attr_reader :last_seen_event_id
    end

    def subscribe(last_seen_event_id, &block)
      @subscribers << Subscriber.new(last_seen_event_id, &block)
    end
  end
end
