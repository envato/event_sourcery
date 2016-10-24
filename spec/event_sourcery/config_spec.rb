RSpec.describe EventSourcery::Config do
  subject(:config) { described_class.new }

  let(:use_optimistic_concurrency) { false }

  context 'when reading the event_store' do
    context 'and an event_store_database is set' do
      before do
        config.event_store_database = double
      end

      context 'and using optimistic concurrency' do
        before do
          config.use_optimistic_concurrency = true
        end

        it 'returns a EventSourcery::EventStore::Postgres::ConnectionWithOptimisticConcurrency' do
          expect(config.event_store).to be_instance_of(EventSourcery::EventStore::Postgres::ConnectionWithOptimisticConcurrency)
        end
      end

      context 'and not using optimistic concurrency' do
        before do
          config.use_optimistic_concurrency = false
        end

        it 'returns a EventSourcery::EventStore::Postgres::Connection' do
          expect(config.event_store).to be_instance_of(EventSourcery::EventStore::Postgres::Connection)
        end
      end
    end

    context 'and an event_store is set' do
      let(:event_store) { double(:event_store) }
      before do
        config.event_store = event_store
        config.event_store_database = nil
      end

      it 'returns the event_store' do
        expect(config.event_store).to eq(event_store)
      end
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

  describe '#inflector' do
    it 'defaults to Utils::String' do
      expect(config.inflector).to eq EventSourcery::Utils::Inflector
    end

    context 'when active support is available' do
      let(:as_inflector) { double }

      before do
        stub_const('ActiveSupport::Inflector', as_inflector)
      end

      it 'uses active support' do
        expect(config.inflector).to eq as_inflector
      end
    end
  end
end
