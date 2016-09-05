module EventSourcery
  module EventStore
    class Subscription
      def initialize(event_store:,
                     poll_waiter:,
                     from_event_id:,
                     event_types: nil,
                     on_new_events:,
                     events_table_name: :events)
        @event_store = event_store
        @from_event_id = from_event_id
        @poll_waiter = poll_waiter
        @event_types = event_types
        @on_new_events = on_new_events
        @current_event_id = from_event_id - 1
      end

      def start
        catch(:stop) do
          @poll_waiter.poll do
            read_events
          end
        end
      end

      private

      def read_events
        loop do
          events = @event_store.get_next_from(@current_event_id + 1, event_types: @event_types)
          break if events.empty?
          @on_new_events.call(events)
          @current_event_id = events.last.id
        end
      end
    end
  end
end
