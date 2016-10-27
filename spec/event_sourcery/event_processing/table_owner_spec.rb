RSpec.describe EventSourcery::EventProcessing::TableOwner do
  let(:table_owner_class) do
    Class.new do
      prepend EventSourcery::EventProcessing::TableOwner

      def initialize(db_connection)
        @db_connection = db_connection
      end

      table :profiles do
        column :uuid, 'UUID'
      end
    end
  end

  subject(:table_owner) { table_owner_class.new(pg_connection) }

  describe '#setup' do
    before do
      pg_connection.execute('DROP TABLE IF EXISTS profiles')
    end

    it 'creates the defines table' do
      table_owner.setup
      expect(pg_connection[:profiles].count).to eq 0
    end
  end

  describe '#reset' do
    before do
      connection.execute('DROP TABLE IF EXISTS profiles')
      table_owner.setup
      pg_connection[:profiles].insert(uuid: SecureRandom.uuid)
    end

    it 'recreates tables' do
      expect(pg_connection[:profiles].count).to eq 1
      table_owner.reset
      expect(pg_connection[:profiles].count).to eq 0
    end
  end
end
