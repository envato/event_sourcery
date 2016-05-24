RSpec.describe EventSourcery::EventFeederAdapters::PostgresPush do
  let(:events) { [] }
  let(:event_source_adapter) { EventSourcery::EventSourceAdapters::Postgres.new(connection) }
  let(:event_source) { EventSourcery::EventSource.new(event_source_adapter) }
  let(:event_bus) { EventSourcery::EventBusAdapters::Postgres.new(connection) }
  let(:event_feeder_adapter) { EventSourcery::EventFeederAdapters::PostgresPush.new(connection, event_source, loop: false, after_listen: proc { notify_new_event(3) }) }
  subject(:event_feeder) { EventSourcery::EventFeeder.new(event_bus, event_source) }

  def notify_new_event(event_id)
    connection.notify('new_event', payload: event_id)
  end

  def insert_event(event_type: 'item_added')
    connection[:events].insert(
      aggregate_id: SecureRandom.uuid,
      type: event_type,
      body: Sequel.pg_json({})
    )
  end

  def publish_event
    connection.notify 'event', payload: EventSourcery::Event.new(id: 4, body: {}).to_h.to_json
  end

  before do
    reset_database
    insert_event
    insert_event(event_type: 'user_signed_up')
    insert_event
  end

  it 'sends events from where the subscriber indicates' do
    first_subscriber_events = []
    second_subscriber_events = []
    event_feeder.subscribe(0) do |events|
      events.each do |event|
        first_subscriber_events << event.id
      end
    end
    event_feeder.subscribe(1, event_types: ['user_signed_up']) do |events|
      events.each do |event|
        second_subscriber_events << event.id
      end
    end
    event_feeder.start!(loop: false, after_listen: proc { publish_event })
    expect(first_subscriber_events).to eq [1, 2, 3, 4]
    expect(second_subscriber_events).to eq [2, 4]
  end
end
