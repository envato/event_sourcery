RSpec.describe EventSourcery::EventProcessing::Projector do
  let(:projector_class) {
    Class.new do
      include EventSourcery::EventProcessing::Projector
      self.processor_name = 'test_processor'

      processes_events :terms_accepted

      table :profiles do
        column :user_uuid, 'UUID NOT NULL'
        column :terms_accepted, 'BOOLEAN DEFAULT FALSE'
      end

      def process(event)
        @processed_event = event
        table.insert(user_uuid: event.aggregate_id,
                     terms_accepted: true)
      end

      attr_reader :processed_event
    end
  }
  let(:projector_name) { 'my_projector' }
  let(:tracker_storage) { EventSourcery::EventProcessing::EventProcessorTrackerAdapters::Postgres.new(connection) }
  let(:tracker) { EventSourcery::EventProcessing::EventProcessorTracker.new(tracker_storage) }
  let(:events) { [] }

  subject(:projector) { projector_class.new(db_connection: connection) }
  let(:aggregate_id) { SecureRandom.uuid }

  after { release_advisory_locks }

  it 'has batch processing enabled' do
    expect(projector_class.batch_processing_enabled?).to eq true
  end

  describe '#setup' do
    before do
      connection.execute('DROP TABLE IF EXISTS profiles')
    end

    it 'creates the defines table' do
      projector.setup
      expect(connection[:profiles].count).to eq 0
    end
  end

  describe '#reset' do
    let(:event) { EventSourcery::Event.new(body: {}, aggregate_id: aggregate_id, type: :terms_accepted, id: 1) }

    before do
      connection.execute('DROP TABLE IF EXISTS profiles')
      projector.setup
      projector.process(event)
    end
  end

  describe '#process' do
    let(:event) { EventSourcery::Event.new(body: {}, aggregate_id: aggregate_id, type: :terms_accepted, id: 1) }

    it "processes events it's interested in" do
      projector.process(event)
      expect(projector.processed_event).to eq(event)
    end

    context 'when an error occurs processing the event' do
      let(:projector_class) {
        Class.new do
          include EventSourcery::Projector
          self.processor_name = 'test_processor'

          processes_events :terms_accepted

          table :profiles do
            column :user_uuid, 'UUID NOT NULL'
            column :terms_accepted, 'BOOLEAN DEFAULT FALSE'
          end

          def process(event)
            table.insert(user_uuid: event.aggregate_id,
                         terms_accepted: true)
            raise 'boo'
          end

          attr_reader :processed_event
        end
      }

      it "the projection insert is rolled back by the transaction" do
        connection[:profiles].delete
        expect(connection[:profiles].count).to eq 0
        projector.process(event) rescue nil
        expect(connection[:profiles].count).to eq 0
      end
    end

    context 'with more than one table' do
      let(:projector_class) {
        Class.new do
          include EventSourcery::EventProcessing::Projector

          processes_events :terms_accepted

          table :profiles do
            column :user_uuid, 'UUID NOT NULL'
            column :terms_accepted, 'BOOLEAN DEFAULT FALSE'
          end

          table :two do
            column :user_uuid, 'UUID NOT NULL'
          end

          def process(event)
            @processed_event = event
            table.insert(user_uuid: event.aggregate_id,
                         terms_accepted: true)
          end

          attr_reader :processed_event
        end
      }

      it 'throws a DefaultTableError when #table is used' do
        expect {
          projector.process(event)
        }.to raise_error(EventSourcery::EventProcessing::TableOwner::DefaultTableError)
      end
    end
  end
end
