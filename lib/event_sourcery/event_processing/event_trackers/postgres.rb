module EventSourcery
  module EventProcessing
    module EventTrackers
      class Postgres
        DEFAULT_TABLE_NAME = :projector_tracker

        def initialize(connection, table_name: DEFAULT_TABLE_NAME, obtain_processor_lock: true)
          @connection = connection
          @table_name = DEFAULT_TABLE_NAME
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
          end
        end

        def tracked_processors
          table.select_map(:name)
        end

        private

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
end
