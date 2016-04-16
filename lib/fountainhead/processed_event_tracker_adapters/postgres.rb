module Fountainhead
  module ProcessedEventTrackerAdapters
    class Postgres
      # TODO: rename table
      TABLE_NAME = :projector_tracker

      def initialize(connection)
        @connection = connection
      end

      def setup(processor_name = nil)
        create_table_if_not_exists
        create_track_entry_if_not_exists(processor_name) if processor_name
      end

      def processed_event(processor_name, event_id)
        rows_changed = table.
          where(name: processor_name.to_s,
                last_processed_event_id: event_id - 1).
                update(last_processed_event_id: event_id)
        if rows_changed == 0
          raise NonSequentialEventProcessingError, "Expected last processed event for processor: #{processor_name} to be #{event_id - 1}, but it was #{last_processed_event_id(processor_name)}"
        end
        true
      end

      def reset_last_processed_event_id(processor_name)
        table.where(name: processor_name.to_s).update(last_processed_event_id: 0)
      end

      def last_processed_event_id(processor_name)
        track_entry = table.where(name: processor_name.to_s).first
        if track_entry
          track_entry[:last_processed_event_id]
        end
      end

      def tracked_processors
        table.select_map(:name)
      end

      private

      def create_table_if_not_exists
        @connection.create_table?(TABLE_NAME) do
          column :name, 'varchar(255) not null'
          column :last_processed_event_id, 'bigint not null default 0'
          index :name, unique: true
        end
      end

      def create_track_entry_if_not_exists(processor_name)
        unless table.where(name: processor_name.to_s).any?
          table.insert(name: processor_name.to_s, last_processed_event_id: 0)
        end
      end

      def table
        @connection[TABLE_NAME]
      end
    end
  end
end
