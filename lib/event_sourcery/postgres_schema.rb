module EventSourcery
  module PostgresSchema
    extend self

    def create(db)
      create_events(db)
      create_aggregates(db)
    end

    def create_events(db)
      db.create_table(:events) do
        primary_key :id, type: Bignum
        column :aggregate_id, 'uuid not null'
        column :type, 'varchar(255) not null'
        column :body, 'json not null'
        column :version, 'bigint not null'
        column :created_at, 'timestamp without time zone not null default (now() at time zone \'utc\')'
        index :aggregate_id
        index :type
        index :created_at
      end
    end

    def create_aggregates(db)
      db.create_table(:aggregates) do
        primary_key :aggregate_id, 'uuid not null'
        column :type, 'varchar(255) not null'
        column :version, 'bigint default 1'
      end
    end
  end
end
