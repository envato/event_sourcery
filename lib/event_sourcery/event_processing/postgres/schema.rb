module EventSourcery
  module EventProcessing
    module Postgres
      module Schema
        extend self

        def create(db: EventSourcery.config.projections_database)
          create_projector_tracker(db: db)
        end

        def create_projector_tracker(db: EventSourcery.config.projections_database)
          db.create_table(:projector_tracker) do
            primary_key :id, type: :Bignum
            column :name, 'varchar(255) not null'
            column :last_processed_event_id, 'bigint not null default 0'
            index :name, unique: true
          end
        end
      end
    end
  end
end
