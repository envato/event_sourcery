module EventSourcery
  class EventSubscriber
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

    def initialize(adapter)
      @adapter = adapter
      @subscribers = []
    end

    def subscribe(last_seen_event_id, &block)
      @subscribers << Subscriber.new(last_seen_event_id, &block)
    end

    def run!(*args)
      @adapter.listen(*args) do |event_id|
        @subscribers.each do |subscriber|
          @adapter.events(from: subscriber.last_seen_event_id + 1, to: event_id) do |event|
            subscriber.call(event)
          end
        end
      end
    end
  end
end
