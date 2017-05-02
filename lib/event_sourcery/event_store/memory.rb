module EventSourcery
  module EventStore
    class Memory
      include EachByRange

      def initialize(events = [], event_builder: EventSourcery.config.event_builder)
        @events = events
        @event_builder = event_builder
      end

      def sink(event_or_events, expected_version: nil)
        events = Array(event_or_events)
        events.each do |event|
          id = @events.size + 1
          serialized_body = EventBodySerializer.serialize(event.body)
          serialized_metadata = EventBodySerializer.serialize(event.metadata)
          @events << @event_builder.build(
            id: id,
            aggregate_id: event.aggregate_id,
            type: event.type,
            body: serialized_body,
            metadata: serialized_metadata,
            created_at: Time.now,
            uuid: event.uuid
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
        event = event_types ? @events.select { |e| event_types.include?(e.type) }.last : @events.last

        event ? event.id : 0
      end

      def get_events_for_aggregate_id(id)
        @events.select { |event| event.aggregate_id == id }
      end
    end
  end
end
