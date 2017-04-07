module DBHelpers
  def pg_connection
    $connection ||= new_connection
  end

  # TODO: switch references to connection to use pg_connection instead
  def connection
    @connection ||= pg_connection
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

  def reset_events_tables
    %w[ events events_without_optimistic_locking ].each do |table|
      connection.execute("truncate table #{table}")
      connection.execute("alter sequence #{table}_id_seq restart with 1")
    end
  end

  def release_advisory_locks
    connection.fetch("SELECT pg_advisory_unlock_all();").to_a
  end
end

RSpec.configure do |config|
  config.include(DBHelpers)
  config.before(:suite) do
    pg_connection = DBHelpers.new_connection
    pg_connection.execute("drop table if exists events")
    pg_connection.execute("drop table if exists aggregates")
    pg_connection.execute("drop table if exists projector_tracker")
    pg_connection.execute("drop table if exists events_without_optimistic_locking")
    EventSourcery::Postgres::Schema.create_event_store(db: pg_connection)
    EventSourcery::Postgres::Schema.create_event_store(db: pg_connection, use_optimistic_concurrency: false, events_table_name: :events_without_optimistic_locking)
    EventSourcery::Postgres::Schema.create_projector_tracker(db: pg_connection)
  end

  config.before do
    reset_events_tables
  end
end
