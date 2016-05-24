module EventSourcery
  module PostgresSchema
    extend self

    def create(db)
      create_events(db)
      create_aggregates(db)
      create_functions(db)
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
    if _expectedVersion = 0 or _expectedVersion is null then
      insert into aggregates(aggregate_id, type, version) values(_aggregateId, _aggregateType, 1);
    else
      raise 'Concurrency conflict. Current version: 0, expected version: %', _expectedVersion;
    end if;
    currentVersion := 0;
  else
    if _expectedVersion is null then
      update aggregates set version=version + 1 where aggregate_id = _aggregateId returning version into _expectedVersion;
    else
      update aggregates set version = version + 1 where aggregate_id = _aggregateId and version = _expectedVersion;
      if not found then
        raise 'Concurrency conflict. Current version: %, expected version: %', currentVersion, _expectedVersion;
        rollback;
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
