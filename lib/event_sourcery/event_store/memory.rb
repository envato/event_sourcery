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
        ensure_one_aggregate(events)
        if expected_version && version_for(events.first.aggregate_id) != expected_version
          raise ConcurrencyError
        end
        events.each do |event|
          id = @events.size + 1
          serialized_body = EventBodySerializer.serialize(event.body)
          @events << @event_builder.build(
            id: id,
            aggregate_id: event.aggregate_id,
            type: event.type,
            version: next_version(event.aggregate_id),
            body: serialized_body,
            created_at: event.created_at || Time.now.utc,
            uuid: event.uuid
          )
        end
        true
      end

      def get_next_from(id, event_types: nil, limit: 1000)
        get_events_by_type(event_types).select { |event| event.id >= id }.first(limit)
      end

      def latest_event_id(event_types: nil)
        event = get_events_by_type(event_types).last
        event.nil? ? 0 : event.id
      end

      def get_events_for_aggregate_id(id)
        @events.select { |event| event.aggregate_id == id }
      end

      def next_version(aggregate_id)
        version_for(aggregate_id) + 1
      end

      def version_for(aggregate_id)
        get_events_for_aggregate_id(aggregate_id).count
      end

      def ensure_one_aggregate(events)
        unless events.map(&:aggregate_id).uniq.count == 1
          raise AtomicWriteToMultipleAggregatesNotSupported
        end
      end

      private

      def get_events_by_type(event_types)
        event_types.nil? ? @events : @events.select { |event| event_types.include?(event.type) }
      end
    end
  end
end
