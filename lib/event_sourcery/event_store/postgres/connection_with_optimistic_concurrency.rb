module EventSourcery
  module EventStore
    module Postgres
      class ConnectionWithOptimisticConcurrency < Connection
        def sink(event_or_events, expected_version: nil)
          events_function_name = EventSourcery.config.write_events_function_name
          events = Array(event_or_events)
          aggregate_ids = events.map(&:aggregate_id).uniq
          raise AtomicWriteToMultipleAggregatesNotSupported unless aggregate_ids.count == 1
          aggregate_id = aggregate_ids.first
          bodies = events.map { |event| @pg_connection.literal(Sequel.pg_json(event.body)) }.join(', ')
          types = events.map { |event| @pg_connection.literal(event.type) }.join(', ')
          sql = <<-SQL
            select #{events_function_name}('#{aggregate_id}'::uuid,
                               array[#{types}]::varchar[],
                               #{expected_version ? expected_version : "null"}::int,
                               array[#{bodies}]::json[],
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
