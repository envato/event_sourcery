module EventSourcery
  module EventFeederAdapters
    class PostgresPush
      def initialize(sequel_connection, event_source, *listen_args)
        @sequel_connection = sequel_connection
        @event_source = event_source
        @postgres_subscriber = NewEventSubscriber.new(sequel_connection)
        @listen_args = listen_args
        @new_event_queue = Queue.new
        @listen_thread = Thread.new { start_event_listener }
      end

      def start!(subscribers)
        catch(:stop) do
          loop do
            event_id = consume_queue
            subscribers.each do |subscriber|
              catch_up_subscriber(subscriber, event_id)
            end
          end
        end
      end

      private

      def catch_up_subscriber(subscriber, event_id)
        @event_source.each_by_range(subscriber.last_seen_event_id + 1, event_id, event_types: subscriber.event_types) do |event|
          subscriber.call(event)
        end
      end

      def start_event_listener
        @postgres_subscriber.listen(*@listen_args) do |event_id|
          @new_event_queue << event_id
        end
      end

      def consume_queue
        throw :stop if !@listen_thread.alive?
        event_id = @new_event_queue.pop
        throw :stop if event_id == :stop
        @new_event_queue.size.times do
          event_id = @new_event_queue.shift
        end
        event_id
      end
    end
  end
end
