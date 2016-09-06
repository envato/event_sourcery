RSpec.describe EventSourcery::EventProcessing::DownstreamEventProcessor do
  let(:dep_class) {
    Class.new do
      include EventSourcery::EventProcessing::DownstreamEventProcessor

      processes_events :terms_accepted

      def process(event)
        @processed_event = event
      end

      attr_reader :processed_event
    end
  }
  let(:dep_class_with_emit) {
    Class.new do
      include EventSourcery::EventProcessing::DownstreamEventProcessor

      processes_events :terms_accepted
      emits_events :blah

      def process(event)
      end
    end
  }

  let(:dep_name) { 'my_dep' }
  let(:event_store) { EventSourcery::EventStore::Memory.new(events) }
  let(:event_source) { EventSourcery::EventStore::EventSource.new(event_store) }

  let(:event_sink) { EventSourcery::EventStore::EventSink.new(event_store) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:events) { [] }
  subject(:dep) { dep_class.new(db_connection: pg_connection, event_source: event_source, event_sink: event_sink) }

  context "a processor that doesn't emit events" do
    it "doesn't require an event sink" do
      expect {
        dep_class.new(event_source: event_source)
      }.to_not raise_error(ArgumentError)
    end

    it "doesn't require an event source" do
      expect {
        dep_class.new(event_sink: event_sink)
      }.to_not raise_error(ArgumentError)
      expect { dep.setup }.to_not raise_error
    end
  end

  context 'a processor that does emit events' do
    it 'requires an event sink' do
      expect {
        dep_class_with_emit.new(event_source: event_source)
      }.to raise_error(ArgumentError)
    end

    it 'requires an event source' do
      expect {
        dep_class_with_emit.new(event_sink: event_sink)
      }.to raise_error(ArgumentError)
    end
  end

  describe '#reset' do
    let(:dep_class) {
      Class.new do
        include EventSourcery::EventProcessing::DownstreamEventProcessor

        processes_events :terms_accepted
        emits_events :blah

        table :test_dep do
          column :uuid, 'UUID NOT NULL'
        end

        def process(event)
          table.insert(uuid: SecureRandom.uuid)
        end
      end
    }

    it 'resets last processed event ID' do
      dep.setup
      dep.process(OpenStruct.new(type: :terms_accepted, id: 1))
      expect(pg_connection[:test_dep].count).to eq 1
      dep.reset
      expect(pg_connection[:test_dep].count).to eq 0
    end
  end

  describe '.processes?' do
    it 'returns true if the event has been defined' do
      expect(dep_class.processes?('terms_accepted')).to eq true
      expect(dep_class.processes?(:terms_accepted)).to eq true
    end

    it "returns false if the event hasn't been defined" do
      expect(dep_class.processes?('item_viewed')).to eq false
      expect(dep_class.processes?(:item_viewed)).to eq false
    end
  end

  describe '.emits_event?' do
    it 'returns true if the event has been defined' do
      expect(dep_class_with_emit.emits_event?('blah')).to eq true
      expect(dep_class_with_emit.emits_event?(:blah)).to eq true
    end

    it "returns false if the event hasn't been defined" do
      expect(dep_class_with_emit.emits_event?('item_viewed')).to eq false
      expect(dep_class_with_emit.emits_event?(:item_viewed)).to eq false
    end

    it "returns false if the DEP doesn't emit events" do
      expect(dep_class.emits_event?('blah')).to eq false
      expect(dep_class.emits_event?(:blah)).to eq false
    end
  end

  it 'allows setting of name' do
    dep_class.processor_name = 'my_processor'
    expect(dep_class.processor_name).to eq 'my_processor'
  end

  it 'has a default processor_name of the class name' do
    allow(dep_class).to receive(:name).and_return('EventSourcery::EventSource')
    expect(dep_class.processor_name).to eq 'EventSourcery::EventSource'
  end

  describe '#process' do
    let(:event) { OpenStruct.new(type: :terms_accepted, id: 1) }

    it "projects events it's interested in" do
      dep.process(event)
      expect(dep.processed_event).to eq(event)
    end

    context "with a type the EventProcessing::DownstreamEventProcessor isn't interested in" do
      let(:event) { OpenStruct.new(type: :item_viewed, id: 1) }

      it "doesn't process unexpected events" do
        dep.process(event)
        expect(dep.processed_event).to eq(nil)
      end
    end

    context 'with a DEP that emits events' do
      let(:event_1) { EventSourcery::Event.new(id: 1, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_2) { EventSourcery::Event.new(id: 2, type: 'echo_event', aggregate_id: aggregate_id, body: event_1.body.merge(EventSourcery::EventProcessing::DownstreamEventProcessor::DRIVEN_BY_EVENT_PAYLOAD_KEY => 1)) }
      let(:event_3) { EventSourcery::Event.new(id: 3, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_4) { EventSourcery::Event.new(id: 4, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_5) { EventSourcery::Event.new(id: 5, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_6) { EventSourcery::Event.new(id: 6, type: 'echo_event', aggregate_id: aggregate_id, body: event_3.body.merge(EventSourcery::EventProcessing::DownstreamEventProcessor::DRIVEN_BY_EVENT_PAYLOAD_KEY => 3)) }
      let(:events) { [event_1, event_2, event_3, event_4] }
      let(:action_stub_class) {
        Class.new do
          def self.action(id)
            actioned << id
          end

          def self.actioned
            @actions ||= []
          end
        end
      }
      let(:dep_class) {
        Class.new do
          include EventSourcery::EventProcessing::DownstreamEventProcessor

          processes_events :terms_accepted
          emits_events :echo_event

          def process(event)
            @event = event
            emit_event(aggregate_id: event.aggregate_id, type: 'echo_event', body: event.body) do
              TestActioner.action(event.id)
            end
          end

          attr_reader :event
        end
      }

      before do
        dep.setup
        stub_const("TestActioner", action_stub_class)
      end

      def event_count
        event_source.get_next_from(0, limit: 100).count
      end

      def latest_events(n = 1)
        event_source.get_next_from(0, limit: 100)[-n..-1]
      end

      it 'releases the clutch after it has processes the latest event captured in setup, not before' do
        [event_1, event_2, event_3, event_4, event_5, event_6].each do |event|
          dep.process(event)
        end
        expect(latest_events(2).map(&:body).map{|b| b[EventSourcery::EventProcessing::DownstreamEventProcessor::DRIVEN_BY_EVENT_PAYLOAD_KEY]}).to eq [4, 5]
      end

      context "when the event emitted doesn't take actions" do
        let(:dep_class) {
          Class.new do
            include EventSourcery::EventProcessing::DownstreamEventProcessor

            processes_events :terms_accepted
            emits_events :echo_event

            def process(event)
              emit_event(aggregate_id: event.aggregate_id, type: 'echo_event', body: event.body)
            end
          end
        }

        it 'processes the events as usual' do
          [event_1, event_2, event_3, event_4, event_5].each do |event|
            dep.process(event)
          end
          expect(event_count).to eq 8
        end
      end

      context "when the event emitted hasn't been defined in emit_events" do
        let(:dep_class) {
          Class.new do
            include EventSourcery::EventProcessing::DownstreamEventProcessor

            processes_events :terms_accepted
            emits_events :echo_event

            def process(event)
              emit_event(aggregate_id: event.aggregate_id, type: 'echo_event_2', body: event.body)
            end
          end
        }

        it 'raises an error' do
          expect {
            dep.process(event_1)
          }.to raise_error(EventSourcery::EventProcessing::DownstreamEventProcessor::UndeclaredEventEmissionError)
        end
      end

      context 'when body is yielded to the emit block' do
        let(:dep_class) {
          Class.new do
            include EventSourcery::EventProcessing::DownstreamEventProcessor

            processes_events :terms_accepted
            emits_events :echo_event

            def process(event)
              emit_event(aggregate_id: event.aggregate_id, type: 'echo_event') do |body|
                body[:token] = 'secret-identifier'
              end
            end
          end
        }

        context 'and the clutch is up' do
          let(:events) { [] }

          it 'can manupulate the event body as part of the action' do
            dep.process(event_1)
            expect(latest_events(1).first.body[:token]).to eq 'secret-identifier'
          end
        end

        context 'and the clutch is down' do
          it "doesn't manipulate events that are already emitted" do
            [event_1, event_2, event_3, event_4].each do |event|
              dep.process(event)
            end
            event_tokens = event_source.get_next_from(0, limit: 4).map {|e| e.body[:token] }.compact
            expect(event_tokens).to eq []
          end

          it 'can manupulate the event body as part of the action' do
            [event_1, event_2, event_3, event_4].each do |event|
              dep.process(event)
            end
            dep.process(event_5)
            expect(latest_events(1).first.body[:token]).to eq 'secret-identifier'
          end
        end
      end
    end
  end
end
