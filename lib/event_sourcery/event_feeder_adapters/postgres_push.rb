module EventSourcery
  module EventFeederAdapters
    class PostgresPush
      def initialize(sequel_connection, event_source, *listen_args)
        @sequel_connection = sequel_connection
        @event_source = event_source
        @postgres_subscriber = NewEventSubscriber.new(sequel_connection)
        @listen_args = listen_args
      end

      def start!(subscribers)
        @postgres_subscriber.listen(*@listen_args) do |event_id|
          subscribers.each do |subscriber|
            catch_up_subscriber(subscriber, event_id)
          end
        end
      end

      private

      def catch_up_subscriber(subscriber, event_id)
        @event_source.each_by_range(subscriber.last_seen_event_id + 1, event_id, event_types: subscriber.event_types) do |event|
          subscriber.call(event)
        end
      end
    end
  end
end
