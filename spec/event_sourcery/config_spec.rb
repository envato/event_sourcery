RSpec.describe EventSourcery::Config do
  subject(:config) { described_class.new }

  let(:use_optimistic_concurrency) { false }

  context 'when reading the event_store' do
    context 'and an event_store_database is set' do
      before do
        config.event_store_database = double
      end

      it 'returns a EventSourcery::Postgres::EventStore' do
        expect(config.event_store).to be_instance_of(EventSourcery::Postgres::EventStore)
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
      expect(config.event_tracker).to be_instance_of(EventSourcery::Postgres::Tracker)
    end
  end
end
