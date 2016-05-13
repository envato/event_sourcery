module EventSourcery
  class EventFeeder
    class Subscriber
      def initialize(last_seen_event_id, event_types: nil, &block)
        @last_seen_event_id = last_seen_event_id
        @event_types = event_types
        @block = block
      end

      def call(events)
        @block.call(events)
        @last_seen_event_id = events.last.id
      end

      attr_reader :last_seen_event_id, :event_types
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
