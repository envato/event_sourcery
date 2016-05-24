module EventSourcery
  module EventSinkAdapters
    class Postgres
      def initialize(connection)
        @connection = connection
      end

      def sink(aggregate_id:, type:, body:, expected_version: nil)
        event_id = nil
        begin
          connection.run <<-SQL
            select writeEvent('#{aggregate_id}'::uuid, '#{type}'::varchar(256), #{expected_version ? expected_version : "null"}::int, #{connection.literal(Sequel.pg_json(body))});
          SQL
        rescue Sequel::DatabaseError => e
          raise ConcurrencyError, "expected version was not #{expected_version}. Error: #{e.message}"
        end
        true
      end

      private

      attr_reader :connection

      def events_table
        @connection[:events]
      end

      def aggregates_table
        @connection[:aggregates]
      end
    end
  end
end
