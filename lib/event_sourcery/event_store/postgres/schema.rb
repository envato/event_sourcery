module EventSourcery
  module EventStore
    module Postgres
      module Schema
        extend self

        def create(db)
          create_events(db)
          create_aggregates(db)
          create_functions(db)
        end

        def create_events(db)
          db.create_table(:events) do
            primary_key :id, type: :Bignum
            column :aggregate_id, 'uuid not null'
            column :type, 'varchar(255) not null'
            column :body, 'json not null'
            column :version, 'bigint not null'
            column :created_at, 'timestamp without time zone not null default (now() at time zone \'utc\')'
            index [:aggregate_id, :version], unique: true
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

        def create_functions(db)
          db.run <<-SQL
create or replace function writeEvent(_aggregateId uuid, _aggregateType varchar(256), _expectedVersion int, _body json) returns void as $$
declare
  currentVersion int;
  event json;
  eventId text;
begin
  select version into currentVersion from aggregates where aggregate_id = _aggregateId;
  if not found then
    -- when we have no existing version for this aggregate
    if _expectedVersion = 0 or _expectedVersion is null then
      -- set the version to 1 if expected version is null or 0
      insert into aggregates(aggregate_id, type, version) values(_aggregateId, _aggregateType, 1);
      currentVersion := 0;
    else
      raise 'Concurrency conflict. Current version: 0, expected version: %', _expectedVersion;
    end if;
  else
    if _expectedVersion is null then
      -- automatically increment the version
      update aggregates set version = version + 1 where aggregate_id = _aggregateId;
    else
      -- increment the version if it's at our expected versionn
      update aggregates set version = version + 1 where aggregate_id = _aggregateId and version = _expectedVersion;
      if not found then
        -- version was not at expected_version, raise an error
        raise 'Concurrency conflict. Current version: %, expected version: %', currentVersion, _expectedVersion;
      end if;
    end if;
  end if;
  insert into events(aggregate_id, type, body, version) values(_aggregateId, _aggregateType, _body, currentVersion + 1) returning id into eventId;
  perform pg_notify('new_event', eventId);
end;
$$ language plpgsql;
SQL
        end
      end
    end
  end
end
