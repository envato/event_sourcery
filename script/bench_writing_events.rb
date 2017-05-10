# Usage:
#
# ❯ bundle exec ruby script/bench_writing_events.rb
# Warming up --------------------------------------
# event_store.sink
#                         70.000  i/100ms
# Calculating -------------------------------------
# event_store.sink
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

def create_schema(pg_connection)
  pg_connection.execute 'drop table if exists events'
  pg_connection.execute 'drop table if exists aggregates'
  EventSourcery::Postgres::Schema.create_event_store(db: pg_connection)
end

create_schema(pg_connection)
event_store = EventSourcery::Postgres::EventStore.new(pg_connection)

def new_event
  EventSourcery::Event.new(type: :item_added,
                           aggregate_id: SecureRandom.uuid,
                           body: { 'something' => 'simple' })
end

Benchmark.ips do |b|
  b.report("event_store.sink") do
    event_store.sink(new_event)
  end
end
