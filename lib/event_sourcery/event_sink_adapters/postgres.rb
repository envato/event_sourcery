module EventSourcery
  module EventSinkAdapters
    class Postgres
      def initialize(connection)
        @connection = connection
      end

      def sink(aggregate_id:, type:, body:, expected_version: nil)
        connection.run <<-SQL
          select writeEvent('#{aggregate_id}'::uuid,
                            '#{type}'::varchar(256),
                            #{expected_version ? expected_version : "null"}::int,
                            #{connection.literal(Sequel.pg_json(body))});
        SQL
        true
      rescue Sequel::DatabaseError => e
        if e.message =~ /Concurrency conflict/
          raise ConcurrencyError, "expected version was not #{expected_version}. Error: #{e.message}"
        else
          raise
        end
      end

      private

      attr_reader :connection
    end
  end
end
