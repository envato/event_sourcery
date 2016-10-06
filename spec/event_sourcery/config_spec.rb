RSpec.describe EventSourcery::Config do
  subject(:config) { described_class.new }

  let(:use_optimistic_concurrency) { false }

  context 'when use_optimistic_concurrency is configured' do
    let(:use_optimistic_concurrency) { false }

    it 'sets the use_optimistic_concurrency flag' do
      config.use_optimistic_concurrency = use_optimistic_concurrency
      expect(config.use_optimistic_concurrency).to eq(false)
    end

    context 'and an event store database has previously been configured' do
      let(:connection) { double }
      let(:use_optimistic_concurrency) { true }
      before do
        allow(EventSourcery::EventStore::Postgres::ConnectionWithOptimisticConcurrency).to receive(:new)
          .with(pg_connection).and_return(connection)
        config.event_store_database = pg_connection
      end

      it 'sets the event store based on the use_optimistic_concurrency value' do
        config.use_optimistic_concurrency = use_optimistic_concurrency
        expect(config.event_store).to eq(connection)
      end
    end
  end

  context 'when the event store database is configured' do
    before do
      config.use_optimistic_concurrency = use_optimistic_concurrency
      config.event_store_database = pg_connection
    end

    context 'and using optimistic concurrency' do
      let(:use_optimistic_concurrency) { true }

      it 'sets the event store as a Postgres::ConnectionWithOptimisticConcurrency' do
        expect(config.event_store).to be_instance_of(
          EventSourcery::EventStore::Postgres::ConnectionWithOptimisticConcurrency
        )
      end
    end

    context 'and not using optimistic concurrency' do
      let(:use_optimistic_concurrency) { false }

      it 'sets the event store as a Postgres::Connection' do
        expect(config.event_store).to be_instance_of(EventSourcery::EventStore::Postgres::Connection)
      end
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
