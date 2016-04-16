RSpec.describe ESFramework::EventSubscriberAdapters::Postgres do
  let(:event_source) { ESFramework::EventSourceAdapters::Postgres.new(connection) }
  let(:event_id) { 5 }
  subject(:adapter) { ESFramework::EventSubscriberAdapters::Postgres.new(connection, event_source) }

  def notify_new_event
    connection.notify('new_event', payload: event_id)
  end

  it 'notifies new events' do
    called_event_id = nil
    adapter.listen(loop: false, after_listen: proc { notify_new_event }) do |event_id|
      called_event_id = event_id
    end
    expect(called_event_id).to eq (event_id)
  end

  context 'when events already exist' do
    def insert_event
      connection[:events].insert(
        aggregate_id: SecureRandom.uuid,
        type: 'blah',
        body: Sequel.pg_json({})
      )
    end

    before do
      insert_event
      @last_event_id = insert_event
    end

    it 'calls the callback with the last event' do
      called_event_id = nil
      adapter.listen do |id|
        called_event_id = id
        throw :stop
      end
      expect(called_event_id).to eq (@last_event_id)
    end
  end

  it 'can stop a forever loop with :stop' do
    # documenting Postgres behaviour
    adapter.listen(after_listen: proc { notify_new_event }) do |event_id|
      throw :stop
    end
  end
end
