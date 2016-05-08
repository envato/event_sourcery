module EventSourcery
  module EventSinkAdapters
    class Postgres
      def initialize(connection)
        @connection = connection
      end

      def sink(aggregate_id:, type:, body:, version:)
        event_id = nil
        connection.transaction do
          result = events_table.
            returning(:id).
            insert(aggregate_id: aggregate_id,
                   type: type.to_s,
                   body: ::Sequel.pg_json(body))
          event_id = result.first.fetch(:id)
          update_aggregate_version(aggregate_id, version)
        end
        connection.notify('new_event', payload: event_id)
        true
      end

      def update_aggregate_version(aggregate_id, version)
        @connection.run <<-SQL
          insert into aggregate_versions (aggregate_id, version)
            values ('#{aggregate_id}', '#{version}')
            on conflict (aggregate_id)
            do update set (version) = (#{version})
        SQL
      end

      private

      attr_reader :events_table, :connection

      def events_table
        @connection[:events]
      end

      def aggregate_versions_table
        @connection[:aggregate_versions]
      end
    end
  end
end
