module EventSourcery
  module EventStore
    module Postgres
      module Schema
        extend self

        def create(db, events_table_name: EventSourcery.config.events_table_name, aggregates_table_name: EventSourcery.config.aggregates_table_name, use_optimistic_concurrency: EventSourcery.config.use_optimistic_concurrency, write_events_function_name: EventSourcery.config.write_events_function_name)
          create_events(db, table_name: events_table_name, use_optimistic_concurrency: use_optimistic_concurrency)
          if use_optimistic_concurrency
            create_aggregates(db, table_name: aggregates_table_name)
            create_or_update_functions(db, events_table_name: events_table_name, function_name: write_events_function_name, aggregates_table_name: aggregates_table_name)
          end
        end

        def create_events(db, table_name: EventSourcery.config.events_table_name, use_optimistic_concurrency: EventSourcery.config.use_optimistic_concurrency)
          db.create_table(table_name) do
            primary_key :id, type: :Bignum
            column :aggregate_id, 'uuid not null'
            column :type, 'varchar(255) not null'
            column :body, 'json not null'
            column :version, 'bigint not null' if use_optimistic_concurrency
            column :created_at, 'timestamp without time zone not null default (now() at time zone \'utc\')'
            if use_optimistic_concurrency
              index [:aggregate_id, :version], unique: true
            else
              index :aggregate_id
            end
            index :type
            index :created_at
          end
        end

        def create_aggregates(db, table_name: EventSourcery.config.aggregates_table_name)
          db.create_table(table_name) do
            primary_key :aggregate_id, 'uuid not null'
            column :version, 'bigint default 1'
          end
        end

        def create_or_update_functions(db, function_name: EventSourcery.config.write_events_function_name, events_table_name: EventSourcery.config.events_table_name, aggregates_table_name: EventSourcery.config.aggregates_table_name)
          db.run <<-SQL
create or replace function #{function_name}(_aggregateId uuid, _eventTypes varchar[], _expectedVersion int, _bodies json[], _lockTable boolean) returns void as $$
declare
  currentVersion int;
  body json;
  eventVersion int;
  eventId text;
  index int;
begin
  select version into currentVersion from #{aggregates_table_name} where aggregate_id = _aggregateId;
  if not found then
    -- when we have no existing version for this aggregate
    if _expectedVersion = 0 or _expectedVersion is null then
      -- set the version to 1 if expected version is null or 0
      insert into #{aggregates_table_name}(aggregate_id, version) values(_aggregateId, 1);
      currentVersion := 0;
    else
      raise 'Concurrency conflict. Current version: 0, expected version: %', _expectedVersion;
    end if;
  else
    if _expectedVersion is null then
      -- automatically increment the version
      update #{aggregates_table_name} set version = version + 1 where aggregate_id = _aggregateId;
    else
      -- increment the version if it's at our expected versionn
      update #{aggregates_table_name} set version = version + 1 where aggregate_id = _aggregateId and version = _expectedVersion;
      if not found then
        -- version was not at expected_version, raise an error
        raise 'Concurrency conflict. Current version: %, expected version: %', currentVersion, _expectedVersion;
      end if;
    end if;
  end if;
  index := 1;
  eventVersion := currentVersion + 1;
  if _lockTable then
    -- ensure this transaction is the only one writing events to guarantee linear growth of sequence IDs
    lock #{events_table_name} in exclusive mode;
  end if;
  foreach body IN ARRAY(_bodies)
  loop
    insert into #{events_table_name}(aggregate_id, type, body, version) values(_aggregateId, _eventTypes[index], body, eventVersion) returning id into eventId;
    eventVersion := eventVersion + 1;
    index := index + 1;
  end loop;
  perform pg_notify('new_event', eventId);
end;
$$ language plpgsql;
SQL
        end
      end
    end
  end
end
