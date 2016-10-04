require 'benchmark/ips' # gem install benchmark-ips
require 'sequel'

pg_uri = ENV.fetch('BOXEN_POSTGRESQL_URL') { 'postgres://127.0.0.1:5432/event_sourcery_test' }
pg_connection = Sequel.connect(pg_uri)

require 'event_sourcery'

EventSourcery.configure do |config|
  config.event_store_database = pg_connection
  config.projections_database = pg_connection
  config.logger.level = :fatal
end

def create_old_events_schema(pg_connection)
  pg_connection.execute 'drop table if exists events_2'
  pg_connection.create_table(:events_2) do
    primary_key :id, type: :Bignum
    column :aggregate_id, 'uuid not null'
    column :type, 'varchar(255) not null'
    column :body, 'json not null'
    column :created_at, 'timestamp without time zone not null default (now() at time zone \'utc\')'
    index :aggregate_id
    index :type
    index :created_at
  end
end

def create_new_events_schema(pg_connection)
  pg_connection.execute 'drop table if exists events'
  pg_connection.execute 'drop table if exists aggregates'
  EventSourcery::EventStore::Postgres::Schema.create(pg_connection)
end

event_store_with_optimistic_concurrency = EventSourcery::EventStore::Postgres::ConnectionWithOptimisticConcurrency.new(pg_connection)
event_store_without_optimistic_concurrency = EventSourcery::EventStore::Postgres::Connection.new(pg_connection, events_table_name: :events_2)

event = EventSourcery::Event.new(type: :item_added,
                                 aggregate_id: SecureRandom.uuid,
                                 body: { 'something' => 'simple' })

create_old_events_schema(pg_connection)
create_new_events_schema(pg_connection)

Benchmark.ips do |b|
  b.report("without_optimistic_concurrency") do
    event_store_without_optimistic_concurrency.sink(event)
  end
  b.report("with_optimistic_concurrency") do
    event_store_with_optimistic_concurrency.sink(event)
  end
end
