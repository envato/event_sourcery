module EventSourcery
  module Postgres
    class EventStore
      include EventSourcery::EventStore::EachByRange

      def initialize(pg_connection, events_table_name: EventSourcery.config.events_table_name, lock_table: EventSourcery.config.lock_table_to_guarantee_linear_sequence_id_growth, write_events_function_name: EventSourcery.config.write_events_function_name, event_builder: EventSourcery.config.event_builder)
        @pg_connection = pg_connection
        @events_table_name = events_table_name
        @write_events_function_name = write_events_function_name
        @lock_table = lock_table
        @event_builder = event_builder
      end

      def sink(event_or_events, expected_version: nil)
        events = Array(event_or_events)
        aggregate_ids = events.map(&:aggregate_id).uniq
        raise AtomicWriteToMultipleAggregatesNotSupported unless aggregate_ids.count == 1
        sql = write_events_sql(aggregate_ids.first, events, expected_version)
        @pg_connection.run(sql)
        log_events_saved(events)
        true
      rescue Sequel::DatabaseError => e
        if e.message =~ /Concurrency conflict/
          raise ConcurrencyError, "expected version was not #{expected_version}. Error: #{e.message}"
        else
          raise
        end
      end

      def get_next_from(id, event_types: nil, limit: 1000)
        query = events_table.
          order(:id).
          where(Sequel.lit('id >= ?', id)).
          limit(limit)
        if event_types
          query = query.where(type: event_types)
        end
        query.map do |event_row|
          build_event(event_row)
        end
      end

      def latest_event_id(event_types: nil)
        latest_event = events_table
        if event_types
          latest_event = latest_event.where(type: event_types)
        end
        latest_event = latest_event.order(:id).last
        if latest_event
          latest_event[:id]
        else
          0
        end
      end

      def get_events_for_aggregate_id(id)
        events_table.where(aggregate_id: id).order(:id).map do |event_hash|
          build_event(event_hash)
        end
      end

      def subscribe(from_id:, event_types: nil, after_listen: nil, subscription_master:, &block)
        poll_waiter = OptimisedEventPollWaiter.new(pg_connection: @pg_connection, after_listen: after_listen)
        args = {
          poll_waiter: poll_waiter,
          event_store: self,
          from_event_id: from_id,
          event_types: event_types,
          events_table_name: @events_table_name,
          subscription_master: subscription_master,
          on_new_events: block
        }
        EventSourcery::EventStore::Subscription.new(args).tap do |s|
          s.start
        end
      end

      private

      def events_table
        @pg_connection[@events_table_name]
      end

      def maybe_lock_table
        if @lock_table
          @pg_connection.transaction do
            @pg_connection.execute "lock #{@events_table_name} in exclusive mode;"
            yield
          end
        else
          yield
        end
      end

      def build_event(data)
        @event_builder.build(data)
      end

      def write_events_sql(aggregate_id, events, expected_version)
        bodies = sql_literal_array(events, 'json', &:body)
        types = sql_literal_array(events, 'varchar', &:type)
        created_ats = sql_literal_array(events, 'timestamp without time zone', &:created_at)
        event_uuids = sql_literal_array(events, 'uuid', &:uuid)
        <<-SQL
          select #{@write_events_function_name}(
            #{sql_literal(aggregate_id, 'uuid')},
            #{types},
            #{sql_literal(expected_version, 'int')},
            #{bodies},
            #{created_ats},
            #{event_uuids},
            #{sql_literal(@lock_table, 'boolean')}
          );
        SQL
      end

      def sql_literal_array(events, type, &block)
        sql_array = events.map do |event|
         to_sql_literal(block.call(event))
        end.join(', ')
        "array[#{sql_array}]::#{type}[]"
      end

      def sql_literal(value, type)
        "#{to_sql_literal(value)}::#{type}"
      end

      def to_sql_literal(value)
        return 'null' unless value
        wrapped_value = if Time === value
          value.iso8601(6)
        elsif Hash === value
          Sequel.pg_json(value)
        else
          value
        end
        @pg_connection.literal(wrapped_value)
      end

      def log_events_saved(events)
        events.each do |event|
          EventSourcery.logger.debug { "Saved event: #{event.inspect}" }
        end
      end
    end
  end
end
