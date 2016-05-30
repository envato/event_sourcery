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

    def initialize(event_bus, event_source)
      @event_bus = event_bus
      @event_source = event_source
    end

    def subscribe(*args, &block)
      subscribers << Subscriber.new(*args, &block)
    end

    def subscribers
      @subscribers ||= []
    end

    def start!(loop: true, after_listen: proc {})
      @event_bus.subscribe(loop: loop, after_listen: proc { catch_up; after_listen.call }) do |event|
        puts "processing event"
        subscribers.each { |s| s.call([event]) }
      end
    end

    def catch_up
      latest_event_id = @event_source.latest_event_id
      subscribers.each do |subscriber|
        catch_up_subscriber(subscriber, latest_event_id)
      end
    end

    def catch_up_subscriber(subscriber, event_id)
      @event_source.fetch_in_batches(subscriber.last_seen_event_id + 1, event_id, event_types: subscriber.event_types) do |events|
        subscriber.call(events) unless events.empty?
      end
    end
  end
end
