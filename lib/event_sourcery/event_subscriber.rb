module EventSourcery
  module EventSubscriber
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
      subscribers << Subscriber.new(last_seen_event_id, &block)
    end

    def subscribers
      @subscribers ||= []
    end
  end
end
