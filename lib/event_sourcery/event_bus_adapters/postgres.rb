# EventBus
#   subscribe {|e| }
# EventSubscription
#   subscribe(0, event_types: [], aggregate_id: )

module EventSourcery
  module EventBusAdapters
    class Postgres
      def initialize(connection, channel: 'event')
        @connection = connection
        @event_queue = Queue.new
        @channel = channel
      end

      def subscribe(loop: true, after_listen: proc {},  &block)
        start_listen_thread(loop: loop, after_listen: after_listen)
        loop do
          break if !@listen_thread.alive?
          yield @event_queue.pop
        end
      end

      def publish(event)
        serialized_event = JSON.dump(event.to_h)
        @connection.notify(@channel, payload: serialized_event)
      end

      private

      def start_listen_thread(loop:, after_listen:)
        @listen_thread = Thread.new { listen_for_events(loop: loop, after_listen: after_listen) }
      end

      def listen_for_events(loop:, after_listen:)
        @connection.listen(@channel, loop: loop,
                                     after_listen: after_listen) do |channel, pid, payload|
          event = Event.new(JSON.parse(payload))
          @event_queue.push(event)
        end
      end
    end
  end
end
