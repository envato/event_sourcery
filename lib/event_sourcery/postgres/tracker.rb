module EventSourcery
  module Postgres
    class Tracker
      DEFAULT_TABLE_NAME = :projector_tracker

      def initialize(connection, table_name: DEFAULT_TABLE_NAME, events_table_name: EventSourcery.config.events_table_name, obtain_processor_lock: true)
        @connection = connection
        @table_name = DEFAULT_TABLE_NAME
        @events_table_name = events_table_name.to_s
        @obtain_processor_lock = obtain_processor_lock
      end

      def setup(processor_name = nil)
        create_table_if_not_exists if EventSourcery.config.auto_create_projector_tracker

        unless tracker_table_exists?
          raise UnableToLockProcessorError, "Projector tracker table does not exist"
        end

        if processor_name
          create_track_entry_if_not_exists(processor_name)
          if @obtain_processor_lock
            if last_actioned_event_id(processor_name).zero?
              value = find_last_actioned_event_id(processor_name)
              if value
                set_last_actioned_event_id(processor_name, value)
              end
            end

            obtain_global_lock_on_processor(processor_name)
          end
        end
      end

      def processed_event(processor_name, event_id)
        table.
          where(name: processor_name.to_s).
                update(last_processed_event_id: event_id)
        true
      end

      def actioned_event(processor_name, event_id)
        table.
          where(name: processor_name.to_s).
                update(last_actioned_event_id: event_id)
        true
      end

      def processing_event(processor_name, event_id)
        @connection.transaction do
          yield
          processed_event(processor_name, event_id)
        end
      end

      def reset_last_processed_event_id(processor_name)
        table.where(name: processor_name.to_s).update(last_processed_event_id: 0)
      end

      def last_processed_event_id(processor_name)
        track_entry = table.where(name: processor_name.to_s).first
        if track_entry
          track_entry[:last_processed_event_id]
        else
          0
        end
      end

      def set_last_actioned_event_id(processor_name, value)
        table.where(name: processor_name.to_s).update(last_actioned_event_id: value)
      end

      def last_actioned_event_id(processor_name)
        track_entry = table.where(name: processor_name.to_s).first
        if track_entry
          track_entry[:last_actioned_event_id]
        else
          0
        end
      end

      def find_last_actioned_event_id(processor_name)
        query = <<-EOF
          SELECT metadata->'causation_id' AS causation_id
          FROM :table
          WHERE metadata->'causation_id' IS NOT NULL
          AND metadata->>'reactor_name' = :reactor_name
          ORDER BY metadata->'causation_id' DESC LIMIT 1;
        EOF
        dataset = @connection.fetch(query,
          table: Sequel.lit(events_table_name),
          reactor_name: processor_name.to_s,
        ).first
        dataset && dataset[:causation_id]
      end

      def tracked_processors
        table.select_map(:name)
      end

      private

      attr_reader :events_table_name

      def obtain_global_lock_on_processor(processor_name)
        lock_obtained = @connection.fetch("select pg_try_advisory_lock(#{@track_entry_id})").to_a.first[:pg_try_advisory_lock]
        if lock_obtained == false
          raise UnableToLockProcessorError, "Unable to get a lock on #{processor_name} #{@track_entry_id}"
        end
      end

      def create_table_if_not_exists
        unless tracker_table_exists?
          EventSourcery.logger.info { "Projector tracker missing - attempting to create 'projector_tracker' table" }
          EventSourcery::Postgres::Schema.create_projector_tracker(db: @connection)
        end
      end

      def create_track_entry_if_not_exists(processor_name)
        track_entry = table.where(name: processor_name.to_s).first
        @track_entry_id = if track_entry
                            track_entry[:id]
                          else
                            table.insert(name: processor_name.to_s, last_processed_event_id: 0)
                          end
      end

      def table
        @connection[@table_name]
      end

      def tracker_table_exists?
        @connection.table_exists?(@table_name)
      end
    end
  end
end
