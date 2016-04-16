module DBHelpers
  def connection
    @connection ||= Sequel.connect(ENV.fetch('EVENT_STORE_DATABASE_URI') { 'postgres://127.0.0.1:15432/identity_event_store_test' })
  end

  def reset_database
    connection.execute('truncate table events')
    connection.execute('alter sequence events_id_seq restart with 1')
  end
end

RSpec.configure do |config|
  config.include(DBHelpers)
end
