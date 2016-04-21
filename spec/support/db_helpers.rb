module DBHelpers
  def connection
    @connection ||= new_connection
  end

  def new_connection
    if ENV['CI']
      Sequel.connect(adapter: 'postgres', database: 'event_sourcery_test')
    else
      Sequel.connect("#{postgres_url}event_sourcery_test")
    end
  end

  def postgres_url
    ENV.fetch('BOXEN_POSTGRESQL_URL') {
      'postgres://buildkite-agent:127.0.0.1:5432/'
    }
  end

  def reset_database
    connection.execute('truncate table events')
    connection.execute('alter sequence events_id_seq restart with 1')
  end
end

RSpec.configure do |config|
  config.include(DBHelpers)
  config.before do
    connection.execute("drop table if exists events")
    EventSourcery::PostgresSchema.create(connection)
  end
end
