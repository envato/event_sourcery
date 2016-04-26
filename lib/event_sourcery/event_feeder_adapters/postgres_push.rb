module EventSourcery
  module EventFeederAdapters
    class PostgresPush
      include EventSubscriber

      def initialize(sequel_connection, event_source)
        @sequel_connection = sequel_connection
        @event_source = event_source
        @postgres_subscriber = NewEventSubscriber.new(sequel_connection)
      end

      def start!(*args)
        @postgres_subscriber.listen(*args) do |event_id|
          subscribers.each do |subscriber|
            catch_up_subscriber(subscriber, event_id)
          end
        end
      end

      private

      def catch_up_subscriber(subscriber, event_id)
        @event_source.each_by_range(subscriber.last_seen_event_id + 1, event_id) do |event|
          subscriber.call(event)
        end
      end
    end
  end
end
