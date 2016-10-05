module EventSourcery
  module EventStore
    class Memory
      include EachByRange

      def initialize(events = [])
        @events = events
      end

      def sink(event_or_events)
        events = Array(event_or_events)
        events.each do |event|
          id = @events.size + 1
          serialized_body = EventBodySerializer.serialize(event.body)
          @events << EventSourcery::Event.new(
            id: id,
            aggregate_id: event.aggregate_id,
            type: event.type,
            body: serialized_body,
            created_at: Time.now
          )
        end
        true
      end

      def get_next_from(id, event_types: nil, limit: 1000)
        events = @events.select { |event| event.id >= id }
        if event_types
          events = events.select { |event| event_types.include?(event.type) }
        end
        events.first(limit)
      end

      def latest_event_id(event_types: nil)
        event = if event_types
                  @events.
                    select { |e| event_types.include?(e.type) }.
                    last
                else
                  @events.last
                end
        if event
          event.id
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

