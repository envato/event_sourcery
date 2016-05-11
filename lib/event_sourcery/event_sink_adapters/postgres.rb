module EventSourcery
  module EventSinkAdapters
    class Postgres
      def initialize(connection)
        @connection = connection
      end

      def sink(aggregate_id:, type:, body:, expected_version: nil)
        event_id = nil
        connection.transaction do
          current_version = aggregate_version(aggregate_id)
          unless current_version
            insert_aggregate_version(aggregate_id, type, 0)
            current_version = 0
          end
          new_version = current_version + 1
          result = events_table.
            returning(:id).
            insert(aggregate_id: aggregate_id,
                   type: type.to_s,
                   body: ::Sequel.pg_json(body),
                   version: new_version)
          event_id = result.first.fetch(:id)
          update_aggregate_version(aggregate_id, new_version, expected_version)
        end
        connection.notify('new_event', payload: event_id)
        true
      end

      def update_aggregate_version(aggregate_id, version, expected_version = nil)
        update_query = @connection[:aggregates].
          where(aggregate_id: aggregate_id)
        if expected_version
          update_query = update_query.where(version: expected_version)
        end
        if update_query.update(version: version) == 0
          raise ConcurrencyError, "expected version was not #{expected_version}"
        end
      end

      def insert_aggregate_version(aggregate_id, type, version)
        @connection.run <<-SQL
          insert into aggregates (aggregate_id, type, version)
            values ('#{aggregate_id}', '#{type}', #{version})
        SQL
      end

      private

      def aggregate_version(aggregate_id)
        result = aggregates_table.
          where(aggregate_id: aggregate_id).
          first
        if result
          result[:version]
        end
      end

      attr_reader :events_table, :connection

      def events_table
        @connection[:events]
      end

      def aggregates_table
        @connection[:aggregates]
      end
    end
  end
end
