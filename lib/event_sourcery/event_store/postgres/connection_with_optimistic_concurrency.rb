module EventSourcery
  module EventStore
    module Postgres
      class ConnectionWithOptimisticConcurrency < Connection
        def sink(event, expected_version: nil)
          @pg_connection.run <<-SQL
            select writeEvent('#{event.aggregate_id}'::uuid,
                              '#{event.type}'::varchar(256),
                              #{expected_version ? expected_version : "null"}::int,
                              #{@pg_connection.literal(Sequel.pg_json(event.body))},
                              #{@lock_table}::boolean);
          SQL
          EventSourcery.logger.debug { "Saved event: #{event.inspect}" }
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
