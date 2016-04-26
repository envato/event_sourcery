module EventSourcery
  class EventFeeder
    class Subscriber
      def initialize(last_seen_event_id, event_type: nil, &block)
        @last_seen_event_id = last_seen_event_id
        @event_type = event_type
        @block = block
      end

      def call(event)
        @block.call(event)
        @last_seen_event_id = event.id
      end

      attr_reader :last_seen_event_id
    end

    def initialize(adapter)
      @adapter = adapter
    end

    def subscribe(*args, &block)
      subscribers << Subscriber.new(*args, &block)
    end

    def subscribers
      @subscribers ||= []
    end

    def start!
      @adapter.start!(subscribers)
    end
  end
end
