# Usage:
#
# ❯ bundle exec ruby script/bench_writing_events.rb
# Warming up --------------------------------------
# without_optimistic_concurrency
#                         60.000  i/100ms
# with_optimistic_concurrency
#                         70.000  i/100ms
# Calculating -------------------------------------
# without_optimistic_concurrency
#                         491.453  (±18.5%) i/s -      2.400k in   5.081030s
# with_optimistic_concurrency
#                         522.007  (±10.9%) i/s -      2.590k in   5.021909s
#
# ^ results from running on a 2016 MacBook

require 'benchmark/ips'
require 'securerandom'
require 'sequel'
require 'event_sourcery'

pg_uri = ENV.fetch('BOXEN_POSTGRESQL_URL') { 'postgres://127.0.0.1:5432/' }.dup
pg_uri << 'event_sourcery_test'
pg_connection = Sequel.connect(pg_uri)

EventSourcery.configure do |config|
  config.event_store_database = pg_connection
  config.projections_database = pg_connection
  config.logger.level = :fatal
end

def create_old_events_schema(pg_connection)
  pg_connection.execute 'drop table if exists events_2'
  EventSourcery::EventStore::Postgres::Schema.create(db: pg_connection, use_optimistic_concurrency: false, events_table_name: 'events_2')
end

def create_new_events_schema(pg_connection)
  pg_connection.execute 'drop table if exists events'
  pg_connection.execute 'drop table if exists aggregates'
  EventSourcery::EventStore::Postgres::Schema.create(db: pg_connection, use_optimistic_concurrency: true)
end

event_store_with_optimistic_concurrency = EventSourcery::EventStore::Postgres::ConnectionWithOptimisticConcurrency.new(pg_connection)
event_store_without_optimistic_concurrency = EventSourcery::EventStore::Postgres::Connection.new(pg_connection, events_table_name: :events_2)

create_old_events_schema(pg_connection)
create_new_events_schema(pg_connection)

def new_event
  EventSourcery::Event.new(type: :item_added,
                           aggregate_id: SecureRandom.uuid,
                           body: { 'something' => 'simple' })
end

Benchmark.ips do |b|
  b.report("without_optimistic_concurrency") do
    event_store_without_optimistic_concurrency.sink(new_event)
  end
  b.report("with_optimistic_concurrency") do
    event_store_with_optimistic_concurrency.sink(new_event)
  end
end
