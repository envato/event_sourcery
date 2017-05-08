RSpec.describe EventSourcery::Postgres::TableOwner do
  let(:table_owner_class) do
    Class.new do
      prepend EventSourcery::Postgres::TableOwner

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

    it 'creates the defined table' do
      table_owner.setup
      expect(pg_connection[:sales].count).to eq 0
    end

    context 'with table_prefix set' do
      before do
        pg_connection.execute('DROP TABLE IF EXISTS my_prefix_sales')
        table_owner.send(:table_prefix=, :my_prefix)
      end

      it 'creates the defined table' do
        table_owner.setup
        expect(pg_connection[:my_prefix_sales].count).to eq 0
      end
    end
  end

  describe '#reset' do
    context 'without dependent tables defined' do
      before do
        pg_connection.execute('DROP TABLE IF EXISTS sales')
        table_owner.setup
        pg_connection[:sales].insert(uuid: SecureRandom.uuid)
      end

      it 'recreates tables' do
        expect(pg_connection[:sales].count).to eq 1
        table_owner.reset
        expect(pg_connection[:sales].count).to eq 0
      end
    end

    context 'with dependent tables defined' do
      let(:table_owner_class) do
        Class.new do
          prepend EventSourcery::Postgres::TableOwner

          def initialize(db_connection)
            @db_connection = db_connection
          end

          table :authors do
            primary_key :id, type: :Integer
            column :uuid, 'UUID'
          end

          table :items do
            foreign_key :authors_id, :authors
            column :created_at, 'timestamp without time zone'
          end
        end
      end

      it 'recreates tables' do
        pg_connection.execute('DROP TABLE IF EXISTS items')
        pg_connection.execute('DROP TABLE IF EXISTS authors')
        table_owner.setup
        pg_connection[:authors].insert(id: 1, uuid: SecureRandom.uuid)
        pg_connection[:items].insert(authors_id: 1, created_at: Time.now)
        expect(pg_connection[:authors].count).to eq 1
        expect(pg_connection[:items].count).to eq 1
        table_owner.reset
        expect(pg_connection[:authors].count).to eq 0
        expect(pg_connection[:items].count).to eq 0
      end
    end

    context 'with table_prefix set' do
      before do
        pg_connection.execute('DROP TABLE IF EXISTS my_prefix_sales')
        table_owner.send(:table_prefix=, :my_prefix)
        table_owner.setup
        pg_connection[:my_prefix_sales].insert(uuid: SecureRandom.uuid)
      end

      it 'recreates tables' do
        expect(pg_connection[:my_prefix_sales].count).to eq 1
        table_owner.reset
        expect(pg_connection[:my_prefix_sales].count).to eq 0
      end
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
          expect { table_owner.send(:table, :some_non_existent_table) }.to raise_error(EventSourcery::Postgres::TableOwner::NoSuchTableError)
        end
      end

      context 'when table_prefix is set' do
        before do
          table_owner.send(:table_prefix=, :my_prefix)
        end

        it 'returns a dataset with the prefixed name' do
          expect(table_owner.send(:table, :sales).opts[:from]).to eq([:my_prefix_sales])
        end
      end
    end

    context 'when multiple tables are defined' do
      let(:table_owner_class) do
        Class.new do
          prepend EventSourcery::Postgres::TableOwner

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
          expect { table_owner.send(:table) }.to raise_error(EventSourcery::Postgres::TableOwner::DefaultTableError)
        end
      end

      context 'with one of the the defined tables as argument' do
        it 'returns a dataset' do
          expect(table_owner.send(:table, :invoices)).to be_a Sequel::Postgres::Dataset
        end
      end

      context 'with the wrong name as argument' do
        it 'raises an error' do
          expect { table_owner.send(:table, :some_non_existent_table) }.to raise_error(EventSourcery::Postgres::TableOwner::NoSuchTableError)
        end
      end
    end
  end
end
