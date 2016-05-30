RSpec.describe EventSourcery::Projector do
  let(:projector_class) {
    Class.new do
      include EventSourcery::Projector
      self.handler_name = 'test_processor'

      handles_events :terms_accepted

      table :profiles do
        column :user_uuid, 'UUID NOT NULL'
        column :terms_accepted, 'BOOLEAN DEFAULT FALSE'
      end

      def handle(event)
        @processed_event = event
        table.insert(user_uuid: event.aggregate_id,
                     terms_accepted: true)
      end

      attr_reader :processed_event
    end
  }
  let(:projector_name) { 'my_projector' }
  let(:events) { [] }

  subject(:projector) {
    projector_class.new(
      db_connection: connection
    )
  }
  let(:aggregate_id) { SecureRandom.uuid }

  after { release_advisory_locks }

  describe '#setup' do
    before do
      connection.execute('DROP TABLE IF EXISTS profiles')
    end

    it 'creates the defines table' do
      projector.setup
      expect(connection[:profiles].count).to eq 0
    end
  end

  describe '#handle' do
    let(:event) { EventSourcery::Event.new(body: {}, aggregate_id: aggregate_id, type: :terms_accepted, id: 1) }

    it "handles events it's interested in" do
      projector.handle(event)
      expect(projector.processed_event).to eq(event)
    end

    context 'when an error occurs handling the event' do
      let(:projector_class) {
        Class.new do
          include EventSourcery::Projector
          self.handler_name = 'test_processor'

          handles_events :terms_accepted

          table :profiles do
            column :user_uuid, 'UUID NOT NULL'
            column :terms_accepted, 'BOOLEAN DEFAULT FALSE'
          end

          def handle(event)
            table.insert(user_uuid: event.aggregate_id,
                         terms_accepted: true)
            raise 'boo'
          end

          attr_reader :processed_event
        end
      }
    end

    context 'with more than one table' do
      let(:projector_class) {
        Class.new do
          include EventSourcery::Projector

          handles_events :terms_accepted

          table :profiles do
            column :user_uuid, 'UUID NOT NULL'
            column :terms_accepted, 'BOOLEAN DEFAULT FALSE'
          end

          table :two do
            column :user_uuid, 'UUID NOT NULL'
          end

          def handle(event)
            @processed_event = event
            table.insert(user_uuid: event.aggregate_id,
                         terms_accepted: true)
          end

          attr_reader :processed_event
        end
      }

      it 'throws a DefaultTableError when #table is used' do
        expect {
          projector.handle(event)
        }.to raise_error(EventSourcery::TableOwner::DefaultTableError)
      end
    end
  end
end
