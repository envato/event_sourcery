RSpec.describe Fountainhead::EventSubscriber do
  let(:events) { [] }
  let(:event_source_adapter) { Fountainhead::EventSourceAdapters::Postgres.new(connection) }
  let(:event_source) { Fountainhead::EventSource.new(event_source_adapter) }
  let(:event_subscriber_adapter) { Fountainhead::EventSubscriberAdapters::Postgres.new(connection, event_source) }
  subject(:event_subscriber) { Fountainhead::EventSubscriber.new(event_subscriber_adapter) }

  def notify_new_event(event_id)
    connection.notify('new_event', payload: event_id)
  end

  def insert_event
    connection[:events].insert(
      aggregate_id: SecureRandom.uuid,
      type: 'blah',
      body: Sequel.pg_json({})
    )
  end

  before do
    reset_database
    insert_event
    insert_event
    insert_event
  end

  it 'sends events from where the subscriber indicates' do
    first_subscriber_events = []
    second_subscriber_events = []
    event_subscriber.subscribe(0) do |event|
      first_subscriber_events << event.id
    end
    event_subscriber.subscribe(1) do |event|
      second_subscriber_events << event.id
    end
    event_subscriber.run!(loop: false, after_listen: proc { notify_new_event(3) })
    expect(first_subscriber_events).to eq [1, 2, 3]
    expect(second_subscriber_events).to eq [2, 3]
  end
end
