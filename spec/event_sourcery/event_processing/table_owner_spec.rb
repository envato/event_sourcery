RSpec.describe EventSourcery::EventProcessing::TableOwner do
  let(:table_owner_class) do
    Class.new do
      prepend EventSourcery::EventProcessing::TableOwner

      def initialize(db_connection)
        @db_connection = db_connection
      end

      table :sales do
        column :uuid, 'UUID'
      end
    end
  end

  subject(:table_owner) { table_owner_class.new(pg_connection) }

  describe '#setup' do
    before do
      pg_connection.execute('DROP TABLE IF EXISTS sales')
    end

    it 'creates the defines table' do
      table_owner.setup
      expect(pg_connection[:sales].count).to eq 0
    end
  end

  describe '#reset' do
    before do
      connection.execute('DROP TABLE IF EXISTS sales')
      table_owner.setup
      pg_connection[:sales].insert(uuid: SecureRandom.uuid)
    end

    it 'recreates tables' do
      expect(pg_connection[:sales].count).to eq 1
      table_owner.reset
      expect(pg_connection[:sales].count).to eq 0
    end
  end

  describe '#table' do
    context 'when one table is defined' do
      context 'with no arguments' do
        it 'returns a dataset' do
          expect(table_owner.send(:table)).to be_a Sequel::Postgres::Dataset
        end
      end

      context 'with the defined table as argument' do
        it 'returns a dataset' do
          expect(table_owner.send(:table, :sales)).to be_a Sequel::Postgres::Dataset
        end
      end

      context 'with the wrong name as argument' do
        it 'raises an error' do
          expect { table_owner.send(:table, :some_non_existent_table) }.to raise_error(EventSourcery::EventProcessing::TableOwner::NoSuchTableError)
        end
      end
    end

    context 'when multiple tables are defined' do
      let(:table_owner_class) do
        Class.new do
          prepend EventSourcery::EventProcessing::TableOwner

          def initialize(db_connection)
            @db_connection = db_connection
          end

          table :sales do
            column :uuid, 'UUID'
          end

          table :invoices do
            column :uuid, 'UUID'
          end
        end
      end

      context 'with no arguments' do
        it 'raises an error' do
          expect { table_owner.send(:table) }.to raise_error(EventSourcery::EventProcessing::TableOwner::DefaultTableError)
        end
      end

      context 'with one of the the defined tables as argument' do
        it 'returns a dataset' do
          expect(table_owner.send(:table, :invoices)).to be_a Sequel::Postgres::Dataset
        end
      end

      context 'with the wrong name as argument' do
        it 'raises an error' do
          expect { table_owner.send(:table, :some_non_existent_table) }.to raise_error(EventSourcery::EventProcessing::TableOwner::NoSuchTableError)
        end
      end
    end
  end
end
