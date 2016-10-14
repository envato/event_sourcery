module EventSourcery
  module EventStore
    module Postgres
      class ConnectionWithOptimisticConcurrency < Connection
        def initialize(pg_connection, events_table_name: EventSourcery.config.events_table_name, lock_table: EventSourcery.config.lock_table_to_guarantee_linear_sequence_id_growth, write_events_function_name: EventSourcery.config.write_events_function_name)
          @pg_connection = pg_connection
          @events_table_name = events_table_name
          @write_events_function_name = write_events_function_name
          @lock_table = lock_table
        end

        def sink(event_or_events, expected_version: nil)
          events = Array(event_or_events)
          aggregate_ids = events.map(&:aggregate_id).uniq
          raise AtomicWriteToMultipleAggregatesNotSupported unless aggregate_ids.count == 1
          aggregate_id = aggregate_ids.first
          bodies = events.map { |event| @pg_connection.literal(Sequel.pg_json(event.body)) }.join(', ')
          types = events.map { |event| @pg_connection.literal(event.type) }.join(', ')
          created_ats = events.map(&:created_at).compact.map { |created_at| "'#{created_at.iso8601(6)}'::timestamp without time zone" }.join(', ')
          if created_ats == ''
            created_ats = "null"
          else
            created_ats = "array[#{created_ats}]"
          end
          sql = <<-SQL
            select #{@write_events_function_name}('#{aggregate_id}'::uuid,
                               array[#{types}]::varchar[],
                               #{expected_version ? expected_version : "null"}::int,
                               array[#{bodies}]::json[],
                               #{created_ats},
                               #{@lock_table}::boolean);
          SQL
          @pg_connection.run sql
          events.each do |event|
            EventSourcery.logger.debug { "Saved event: #{event.inspect}" }
          end
          true
        rescue Sequel::DatabaseError => e
          if e.message =~ /Concurrency conflict/
            raise ConcurrencyError, "expected version was not #{expected_version}. Error: #{e.message}"
          else
            raise
          end
        end
      end
    end
  end
end
