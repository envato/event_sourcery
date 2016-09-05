module EventSourcery
  module EventStore
    module Postgres
      class Subscription
        def initialize(event_store:,
                       poll_waiter:,
                       from_event_id:,
                       event_types: nil,
                       on_new_event:,
                       events_table_name: :events)
          @event_store = event_store
          @from_event_id = from_event_id
          @poll_waiter = poll_waiter
          @event_types = event_types
          @on_new_event = on_new_event
          @current_event_id = from_event_id
        end

        def start
          @poll_waiter.poll(after_listen: proc { read_events }) do
            read_events
          end
        end

        private

        def read_events
          loop do
            events = @event_store.get_next_from(@current_event_id)
            break if events.empty?
            events.each do |event|
              @on_new_event.call(event)
              @current_event_id = event.id
            end
          end
        end
      end
    end
  end
end
