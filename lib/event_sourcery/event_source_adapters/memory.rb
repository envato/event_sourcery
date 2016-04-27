module EventSourcery
  module EventSourceAdapters
    class Memory
      def initialize(events = {})
        @events = events
      end

      def get_next_from(id, event_types: nil, limit: 1000)
        events = @events.select { |event| event.id >= id }
        if event_types
          events = events.select { |event| event_types.include?(event.type) }
        end
        events.first(limit)
      end

      def latest_event_id
        last_event = @events.last
        if last_event
          last_event.id
        else
          0
        end
      end

      def get_events_for_aggregate_id(id)
        @events.select { |event|
          event.aggregate_id == id
        }
      end
    end
  end
end
