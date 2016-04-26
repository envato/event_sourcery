module EventSourcery
  module EventSourceAdapters
    class Postgres
      def initialize(connection)
        @connection = connection
        @events_table = connection[:events]
      end

      def get_next_from(id, event_type: nil, limit: 1000)
        query = events_table.
          order(:id).
          where('id >= :from_id',
                from_id: id).
          limit(limit)
        if event_type
          query = query.where(type: event_type)
        end
        query.map do |event_row|
          Event.new(event_row)
        end
      end

      def latest_event_id
        latest_event = events_table.order(:id).last
        if latest_event
          latest_event[:id]
        else
          0
        end
      end

      def get_events_for_aggregate_id(id)
        events_table.where(aggregate_id: id).order(:id).map do |event_hash|
          Event.new(event_hash)
        end
      end

      private

      attr_reader :events_table
    end
  end
end
