module EventSourcery
  module Memory
    # In-memory event store.
    #
    # Note: This is not persisted and is generally used for testing.
    class EventStore
      include EventSourcery::EventStore::EachByRange

      #
      # @param events [Array] Optional. Collection of events
      # @param event_builder Optional. Event builder instance. Will default to {Config#event_builder}
      def initialize(events = [], event_builder: EventSourcery.config.event_builder)
        @events = events
        @event_builder = event_builder
      end

      # Store given events to the in-memory store
      #
      # @param event_or_events Event(s) to be stored
      # @param expected_version [Optional] Expected version for the aggregate. This is the version the caller of this method expect the aggregate to be in. If it's different from the expected version a {EventSourcery::ConcurrencyError} will be raised. Defaults to nil.
      # @raise EventSourcery::ConcurrencyError
      # @return Boolean
      def sink(event_or_events, expected_version: nil)
        events = Array(event_or_events)
        ensure_one_aggregate(events)

        if expected_version && version_for(events.first.aggregate_id) != expected_version
          raise ConcurrencyError
        end

        events.each do |event|
          @events << @event_builder.build(
            id: @events.size + 1,
            aggregate_id: event.aggregate_id,
            type: event.type,
            version: next_version(event.aggregate_id),
            body: EventBodySerializer.serialize(event.body),
            created_at: event.created_at || Time.now.utc,
            uuid: event.uuid,
            correlation_id: event.correlation_id,
            causation_id: event.causation_id,
          )
        end

        true
      end

      # Retrieve a subset of events
      #
      # @param id Starting from event ID
      # @param event_types [Array] Optional. If supplied, only retrieve events of given type(s).
      # @param limit [Integer] Optional. Number of events to retrieve (starting from the given event ID).
      # @return Array
      def get_next_from(id, event_types: nil, limit: 1000)
        events = if event_types.nil?
          @events
        else
          @events.select { |e| event_types.include?(e.type) }
        end

        events.select { |event| event.id >= id }.first(limit)
      end

      # Retrieve the latest event ID
      #
      # @param event_types [Array] Optional. If supplied, only retrieve events of given type(s).
      # @return Integer
      def latest_event_id(event_types: nil)
        events = if event_types.nil?
          @events
        else
          @events.select { |e| event_types.include?(e.type) }
        end

        events.empty? ? 0 : events.last.id
      end

      # Get all events for the given aggregate
      #
      # @param id [String] Aggregate ID (UUID as String)
      # @return Array
      def get_events_for_aggregate_id(id)
        stringified_id = id.to_str
        @events.select { |event| event.aggregate_id == stringified_id }
      end

      # Next version for the aggregate
      #
      # @param aggregate_id [String] Aggregate ID (UUID as String)
      # @return Integer
      def next_version(aggregate_id)
        version_for(aggregate_id) + 1
      end

      # Current version for the aggregate
      #
      # @param aggregate_id [String] Aggregate ID (UUID as String)
      # @return Integer
      def version_for(aggregate_id)
        get_events_for_aggregate_id(aggregate_id).count
      end

      # Ensure all events have the same aggregate
      #
      # @param events [Array] Collection of events
      # @raise AtomicWriteToMultipleAggregatesNotSupported
      def ensure_one_aggregate(events)
        unless events.map(&:aggregate_id).uniq.one?
          raise AtomicWriteToMultipleAggregatesNotSupported
        end
      end
    end
  end
end
