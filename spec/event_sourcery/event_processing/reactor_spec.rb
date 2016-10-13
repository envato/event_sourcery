RSpec.describe EventSourcery::EventProcessing::Reactor do
  let(:dep_class) {
    Class.new do
      include EventSourcery::EventProcessing::Reactor

      processes_events :terms_accepted

      def process(event)
        @processed_event = event
      end

      attr_reader :processed_event
    end
  }
  let(:dep_class_with_emit) {
    Class.new do
      include EventSourcery::EventProcessing::Reactor

      processes_events :terms_accepted
      emits_events :blah

      def process(event)
      end
    end
  }

  let(:tracker) { EventSourcery::EventProcessing::EventTrackers::Memory.new }
  let(:dep_name) { 'my_dep' }
  let(:event_store) { EventSourcery::EventStore::Memory.new(events) }
  let(:event_source) { EventSourcery::EventStore::EventSource.new(event_store) }

  let(:event_sink) { EventSourcery::EventStore::EventSink.new(event_store) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:events) { [] }
  subject(:dep) { dep_class.new(tracker: tracker, event_source: event_source, event_sink: event_sink) }

  context "a processor that doesn't emit events" do
    it "doesn't require an event sink" do
      expect {
        dep_class.new(tracker: tracker, event_source: event_source)
      }.to_not raise_error(ArgumentError)
    end

    it "doesn't require an event source" do
      expect {
        dep_class.new(tracker: tracker, event_sink: event_sink)
      }.to_not raise_error(ArgumentError)
      expect { dep.setup }.to_not raise_error
    end
  end

  context 'a processor that does emit events' do
    it 'requires an event sink' do
      expect {
        dep_class_with_emit.new(tracker, event_source, nil)
      }.to raise_error(ArgumentError)
    end

    it 'requires an event source' do
      expect {
        dep_class_with_emit.new(tracker, nil, event_sink)
      }.to raise_error(ArgumentError)
    end
  end

  describe '#setup' do
    it 'sets up the tracker to ensure we have a track entry' do
      expect(tracker).to receive(:setup).with(dep_class.processor_name)
      dep.setup
    end
  end

  describe '#reset' do
    it 'resets last processed event ID' do
      dep.process(OpenStruct.new(type: :terms_accepted, id: 1))
      dep.reset
      expect(tracker.last_processed_event_id(:test_processor)).to eq 0
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

  describe '#process' do
    let(:event) { OpenStruct.new(type: :terms_accepted, id: 1) }

    it "projects events it's interested in" do
      dep.process(event)
      expect(dep.processed_event).to eq(event)
    end

    context 'with a DEP that emits events' do
      let(:event_1) { EventSourcery::Event.new(id: 1, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_2) { EventSourcery::Event.new(id: 2, type: 'echo_event', aggregate_id: aggregate_id, body: event_1.body.merge(EventSourcery::EventProcessing::Reactor::DRIVEN_BY_EVENT_PAYLOAD_KEY => 1)) }
      let(:event_3) { EventSourcery::Event.new(id: 3, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_4) { EventSourcery::Event.new(id: 4, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_5) { EventSourcery::Event.new(id: 5, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_6) { EventSourcery::Event.new(id: 6, type: 'echo_event', aggregate_id: aggregate_id, body: event_3.body.merge(EventSourcery::EventProcessing::Reactor::DRIVEN_BY_EVENT_PAYLOAD_KEY => 3)) }
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
          include EventSourcery::EventProcessing::Reactor

          processes_events :terms_accepted
          emits_events :echo_event

          def process(event)
            @event = event
            emit_event(EventSourcery::Event.new(aggregate_id: event.aggregate_id, type: 'echo_event', body: event.body)) do
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

      context "when the event emitted doesn't take actions" do
        let(:dep_class) {
          Class.new do
            include EventSourcery::EventProcessing::Reactor

            processes_events :terms_accepted
            emits_events :echo_event

            def process(event)
              emit_event(EventSourcery::Event.new(aggregate_id: event.aggregate_id, type: 'echo_event', body: event.body))
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
            include EventSourcery::EventProcessing::Reactor

            processes_events :terms_accepted
            emits_events :echo_event

            def process(event)
              emit_event(EventSourcery::Event.new(aggregate_id: event.aggregate_id, type: 'echo_event_2', body: event.body))
            end
          end
        }

        it 'raises an error' do
          expect {
            dep.process(event_1)
          }.to raise_error(EventSourcery::EventProcessing::Reactor::UndeclaredEventEmissionError)
        end
      end

      context 'when body is yielded to the emit block' do
        let(:events) { [] }
        let(:dep_class) {
          Class.new do
            include EventSourcery::EventProcessing::Reactor

            processes_events :terms_accepted
            emits_events :echo_event

            def process(event)
              emit_event(EventSourcery::Event.new(aggregate_id: event.aggregate_id, type: 'echo_event')) do |body|
                body[:token] = 'secret-identifier'
              end
            end
          end
        }

        it 'can manupulate the event body as part of the action' do
          dep.process(event_1)
          expect(latest_events(1).first.body["token"]).to eq 'secret-identifier'
        end

        it 'stores the driven by event id in the body' do
          dep.process(event_1)
          expect(latest_events(1).first.body["_driven_by_event_id"]).to eq event_1.id
        end
      end

      it 'can emit events with a hash instead of an event object' do
        dep = Class.new do
          include EventSourcery::EventProcessing::Reactor

          processes_events :terms_accepted
          emits_events :echo_event

          def process(event)
            emit_event(aggregate_id: event.aggregate_id, type: 'echo_event') do |body|
              body[:token] = 'secret-identifier'
            end
          end
        end.new(tracker: tracker, event_source: event_source, event_sink: event_sink)
        event = new_event(id: 1, type: :terms_accepted, aggregate_id: SecureRandom.uuid)
        dep.process(event)
        expect(latest_events(1).first.body["_driven_by_event_id"]).to eq event.id
        expect(latest_events(1).first.body["token"]).to eq 'secret-identifier'
        expect(latest_events(1).first.aggregate_id).to eq event.aggregate_id
      end
    end
  end
end
