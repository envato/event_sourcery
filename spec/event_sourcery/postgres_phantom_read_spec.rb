RSpec.describe 'phantom read' do
  let(:queue_a) { Queue.new }
  let(:queue_b) { Queue.new }

  def insert_event(connection, options = {})
    connection.transaction(options) do
      connection[:events].
        insert(aggregate_id: SecureRandom.uuid,
               type: 'my_event',
               body: ::Sequel.pg_json({}))
      yield if block_given?
    end
  end

  def all_event_ids(connection)
    connection[:events].select(:id).to_a.map do |event_hash|
      event_hash[:id]
    end
  end

  it "doesn't select the event ID still in a transaction" do
    # step 1: insert first event
    insert_event(connection)
    Thread.new do
      insert_event(new_connection) do
        # step 2: start a transaction with a new event inserted but not yet
        # committed
        queue_a.push :go
        # step 3: block inside the transaction step 6 executes
        queue_b.pop
      end
      # step 7: get ready to see a phantom
      queue_a.push :go
    end
    queue_a.pop
    # step 4: insert another event
    insert_event(connection)
    # step 5: select event ID array
    expect(all_event_ids(connection)).to eq([1, 3])
    # step 6: release the transaction and wait for it to be committed
    queue_b.push :go
    queue_a.pop
    # step 8: see a phantom
    expect(all_event_ids(connection)).to eq([1, 2, 3])
  end
end
