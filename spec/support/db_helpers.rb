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

  def reset_database
    pg_connection.execute('truncate table aggregates')
    %w[ events events_without_optimistic_locking ].each do |table|
      pg_connection.execute("truncate table #{table}")
      pg_connection.execute("alter sequence #{table}_id_seq restart with 1")
    end
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
  config.before(:suite) { DBHelpers.recreate_database }
  config.before(:example) { DBHelpers.reset_database }
end
