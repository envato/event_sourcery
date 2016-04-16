module Fountainhead
  module PostgresSchema
    extend self

    def create(db)
      db.create_table(:events) do
        primary_key :id, type: Bignum
        column :aggregate_id, 'uuid not null'
        column :type, 'varchar(255) not null'
        column :body, 'json not null'
        column :created_at, 'timestamp without time zone not null default (now() at time zone \'utc\')'
        index :aggregate_id
        index :type
        index :created_at
      end
    end
  end
end
