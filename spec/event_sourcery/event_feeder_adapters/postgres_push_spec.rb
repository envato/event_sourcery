RSpec.describe EventSourcery::EventFeederAdapters::PostgresPush do
  let(:events) { [] }
  let(:event_source_adapter) { EventSourcery::EventSourceAdapters::Postgres.new(connection) }
  let(:event_source) { EventSourcery::EventSource.new(event_source_adapter) }
  let(:event_feeder_adapter) { EventSourcery::EventFeederAdapters::PostgresPush.new(connection, event_source, loop: false, after_listen: proc { notify_new_event(3) }) }
  subject(:event_feeder) { EventSourcery::EventFeeder.new(event_feeder_adapter) }

  def notify_new_event(event_id)
    connection.notify('new_event', payload: event_id)
  end

  def insert_event(event_type: 'item_added')
    connection[:events].insert(
      aggregate_id: SecureRandom.uuid,
      type: event_type,
      body: Sequel.pg_json({}),
      version: 1 # TODO: use event sink
    )
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
    event_feeder.subscribe(0) do |event|
      first_subscriber_events << event.id
    end
    event_feeder.subscribe(1, event_types: ['user_signed_up']) do |event|
      second_subscriber_events << event.id
    end
    event_feeder.start!
    expect(first_subscriber_events).to eq [1, 2, 3]
    expect(second_subscriber_events).to eq [2]
  end
end
