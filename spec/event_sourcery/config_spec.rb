RSpec.describe EventSourcery::Config do
  subject(:config) { described_class.new }

  context 'when the event store database is configured' do
    before do
      config.event_store_database = pg_connection
    end

    it 'sets the event store' do
      expect(config.event_store).to be_instance_of(EventSourcery::EventStore::Postgres::Connection)
    end

    it 'sets the event sink' do
      expect(config.event_sink).to be_instance_of(EventSourcery::EventStore::EventSink)
    end

    it 'sets the event source' do
      expect(config.event_source).to be_instance_of(EventSourcery::EventStore::EventSource)
    end
  end

  context 'setting the projections database' do
    before do
      config.projections_database = pg_connection
    end

    it 'sets the projections_database' do
      expect(config.projections_database).to eq pg_connection
    end

    it 'sets the event_tracker' do
      expect(config.event_tracker).to be_instance_of(EventSourcery::EventProcessing::EventTrackers::Postgres)
    end
  end
end
