module EventSourcery
  module EventSinkAdapters
    class Postgres
      def initialize(connection)
        @connection = connection
      end

      def sink(aggregate_id:, type:, body:, expected_version: nil)
        event_id = nil
        connection.transaction do
          new_version = resolve_new_aggregate_version(aggregate_id, type, expected_version)
          result = events_table.
            returning(:id).
            insert(aggregate_id: aggregate_id,
                   type: type.to_s,
                   body: ::Sequel.pg_json(body),
                   version: new_version)
          event_id = result.first.fetch(:id)
        end
        connection.notify('new_event', payload: event_id)
        true
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

      def resolve_new_aggregate_version(aggregate_id, type, expected_version)
        current_version = aggregate_version(aggregate_id)
        if current_version
          if expected_version.nil?
            new_version = increment_aggregate_version(aggregate_id)
          else
            new_version = current_version + 1
            update_aggregate_version(aggregate_id, new_version, expected_version)
          end
        else
          insert_aggregate_version(aggregate_id, type, 1)
          new_version = 1
        end
        new_version
      end

      def update_aggregate_version(aggregate_id, version, expected_version)
        update_query = aggregates_table.
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

      def increment_aggregate_version(aggregate_id)
        aggregates_table.
          where(aggregate_id: aggregate_id).
          returning(:version).
          update(version: Sequel.expr(:version) + 1).first[:version]
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
