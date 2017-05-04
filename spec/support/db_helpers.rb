require 'database_cleaner'

module DBHelpers
  extend self

  def pg_connection
    $connection ||= new_connection
  end

  module_function def new_connection
    if ENV['CI']
      Sequel.connect(adapter: 'postgres', database: 'event_sourcery_test')
    else
      Sequel.connect("#{postgres_url}event_sourcery_test")
    end
  end

  module_function def postgres_url
    if ENV['BUILDKITE']
      'postgres://buildkite-agent:127.0.0.1:5432/'
    else
      ENV.fetch('BOXEN_POSTGRESQL_URL') {
        'postgres://127.0.0.1:5432/'
      }
    end
  end

  def reset_sequences
    pg_connection.fetch("SELECT relname FROM pg_class WHERE relkind = 'S'").map { |row| row[:relname] }.each do |rel_name|
      pg_connection.execute("alter sequence #{rel_name} restart with 1")
    end
  end

  def configure_database_cleaner
    DatabaseCleaner[:sequel, connection: pg_connection]
    DatabaseCleaner.strategy = :truncation
  end

  def recreate_database
    pg_connection.execute("drop table if exists events")
    pg_connection.execute("drop table if exists events_without_optimistic_locking")
    pg_connection.execute("drop table if exists aggregates")
    pg_connection.execute("drop table if exists projector_tracker")
    EventSourcery::Postgres::Schema.create_event_store(db: pg_connection, use_optimistic_concurrency: true)
    EventSourcery::Postgres::Schema.create_event_store(db: pg_connection, use_optimistic_concurrency: false, events_table_name: :events_without_optimistic_locking)
    EventSourcery::Postgres::Schema.create_projector_tracker(db: pg_connection)
  end

  def release_advisory_locks(connection=pg_connection)
    connection.fetch("SELECT pg_advisory_unlock_all();").to_a
  end
end

RSpec.configure do |config|
  config.include(DBHelpers)

  config.before :suite do
    DBHelpers.recreate_database
    DBHelpers.configure_database_cleaner
  end

  config.before :each do
    DBHelpers.reset_sequences
    DatabaseCleaner.clean
  end
end
