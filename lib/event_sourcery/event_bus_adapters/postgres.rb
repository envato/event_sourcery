# EventBus
#   subscribe {|e| }
# EventSubscription
#   subscribe(0, event_types: [], aggregate_id: )

module EventSourcery
  module EventBusAdapters
    class Postgres
      def initialize(connection, channel: 'event')
        @connection = connection
        @channel = channel
      end

      def subscribe(loop: true, after_listen: proc {},  &block)
        @connection.listen(@channel, loop: loop,
                                     after_listen: after_listen) do |channel, pid, payload|
          event = Event.new(JSON.parse(payload))
          yield event
        end
      end

      def publish(event)
        serialized_event = JSON.dump(event.to_h)
        @connection.notify(@channel, payload: serialized_event)
      end
    end
  end
end
