module EventSourcery
  module EventStore
    class Subscription
      def initialize(event_store:,
                     poll_waiter:,
                     from_event_id:,
                     event_types: nil,
                     on_new_events:,
                     subscription_master:,
                     events_table_name: :events)
        @event_store = event_store
        @from_event_id = from_event_id
        @poll_waiter = poll_waiter
        @event_types = event_types
        @on_new_events = on_new_events
        @subscription_master = subscription_master
        @current_event_id = from_event_id - 1
      end

      def start
        catch(:stop) do
          begin
            @poll_waiter.poll do
              read_events
            end
          rescue => e
            @poll_waiter.shutdown!
            raise
          end
        end
      end

      private

      def read_events
        @subscription_master.shutdown_if_requested
        loop do
          events = @event_store.get_next_from(@current_event_id + 1, event_types: @event_types)
          break if events.empty?
          EventSourcery.logger.debug { "New events in subscription: #{events.inspect}" }
          @on_new_events.call(events)
          @current_event_id = events.last.id
          EventSourcery.logger.debug { "Position in stream: #{@current_event_id}" }
        end
      end
    end
  end
end
