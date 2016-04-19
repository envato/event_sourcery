module EventSourcery
  module EventSinkAdapters
    class Postgres
      def initialize(connection)
        @connection = connection
        @events_table = connection[:events]
      end

      def sink(aggregate_id:, type:, body:)
        connection.transaction do
          result = events_table.
            returning(:id).
            insert(aggregate_id: aggregate_id,
                   type: type.to_s,
                   body: ::Sequel.pg_json(body))
          event_id = result.first.fetch(:id)
          connection.notify('new_event', payload: event_id)
          true
        end
      end

      private

      attr_reader :events_table, :connection
    end
  end
end
