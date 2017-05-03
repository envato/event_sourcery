RSpec.describe EventSourcery::Postgres::Reactor do
  let(:reactor_class) {
    Class.new do
      include EventSourcery::Postgres::Reactor

      processes_events :terms_accepted

      def process(event)
        @processed_event = event
      end

      attr_reader :processed_event
    end
  }
  let(:reactor_class_with_emit) {
    Class.new do
      include EventSourcery::Postgres::Reactor

      processes_events :terms_accepted
      emits_events :blah

      def process(event)
      end
    end
  }

  let(:tracker) { EventSourcery::Postgres::Tracker.new(pg_connection) }
  # TODO: Should we be using pg event store here?
  let(:event_store) { EventSourcery::EventStore::Memory.new(events) }
  let(:event_source) { EventSourcery::EventStore::EventSource.new(event_store) }

  let(:event_sink) { EventSourcery::EventStore::EventSink.new(event_store) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:events) { [] }
  subject(:reactor) { reactor_class.new(tracker: tracker, event_source: event_source, event_sink: event_sink) }
  let(:driven_by_event_payload_key) { EventSourcery::Postgres::Reactor::DRIVEN_BY_EVENT_PAYLOAD_KEY }

  describe '.new' do
    let(:event_source) { double }
    let(:event_sink) { double }
    let(:projections_database) { double }
    let(:event_tracker) { double }

    before do
      allow(EventSourcery::Postgres::Tracker).to receive(:new).with(projections_database).and_return(event_tracker)

      EventSourcery.configure do |config|
        config.event_source = event_source
        config.event_sink = event_sink
        config.projections_database = projections_database
      end
    end

    subject(:reactor) { reactor_class.new }

    it 'uses the configured projections database by default' do
      expect(reactor.instance_variable_get('@db_connection')).to eq projections_database
    end

    it 'uses the inferred event tracker database by default' do
      expect(reactor.instance_variable_get('@tracker')).to eq event_tracker
    end

    it 'uses the configured event source by default' do
      expect(reactor.instance_variable_get('@event_source')).to eq event_source
    end

    it 'uses the configured event sink by default' do
      expect(reactor.instance_variable_get('@event_sink')).to eq event_sink
    end
  end

  context "a processor that doesn't emit events" do
    it "doesn't require an event sink" do
      expect {
        reactor_class.new(tracker: tracker, event_source: event_source)
      }.to_not raise_error
    end

    it "doesn't require an event source" do
      expect {
        reactor_class.new(tracker: tracker, event_sink: event_sink)
      }.to_not raise_error
      expect { reactor.setup }.to_not raise_error
    end
  end

  context 'a processor that does emit events' do
    it 'requires an event sink' do
      expect {
        reactor_class_with_emit.new(tracker, event_source, nil)
      }.to raise_error(ArgumentError)
    end

    it 'requires an event source' do
      expect {
        reactor_class_with_emit.new(tracker, nil, event_sink)
      }.to raise_error(ArgumentError)
    end
  end

  describe '#setup' do
    it 'sets up the tracker to ensure we have a track entry' do
      expect(tracker).to receive(:setup).with(reactor_class.processor_name)
      reactor.setup
    end
  end

  describe '#reset' do
    it 'resets last processed event ID' do
      reactor.process(OpenStruct.new(type: :terms_accepted, id: 1))
      reactor.reset
      expect(tracker.last_processed_event_id(:test_processor)).to eq 0
    end
  end

  describe '.processes?' do
    it 'returns true if the event has been defined' do
      expect(reactor_class.processes?('terms_accepted')).to eq true
      expect(reactor_class.processes?(:terms_accepted)).to eq true
    end

    it "returns false if the event hasn't been defined" do
      expect(reactor_class.processes?('item_viewed')).to eq false
      expect(reactor_class.processes?(:item_viewed)).to eq false
    end
  end

  describe '.emits_event?' do
    it 'returns true if the event has been defined' do
      expect(reactor_class_with_emit.emits_event?('blah')).to eq true
      expect(reactor_class_with_emit.emits_event?(:blah)).to eq true
    end

    it "returns false if the event hasn't been defined" do
      expect(reactor_class_with_emit.emits_event?('item_viewed')).to eq false
      expect(reactor_class_with_emit.emits_event?(:item_viewed)).to eq false
    end

    it "returns false if the reactor doesn't emit events" do
      expect(reactor_class.emits_event?('blah')).to eq false
      expect(reactor_class.emits_event?(:blah)).to eq false
    end
  end

  describe '#process' do
    let(:event) { OpenStruct.new(type: :terms_accepted, id: 1) }

    it "projects events it's interested in" do
      reactor.process(event)
      expect(reactor.processed_event).to eq(event)
    end

    context 'with a reactor that emits events' do
      let(:event_1) { EventSourcery::Event.new(id: 1, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_2) { EventSourcery::Event.new(id: 2, type: 'echo_event', aggregate_id: aggregate_id, body: event_1.body.merge(driven_by_event_payload_key => 1)) }
      let(:event_3) { EventSourcery::Event.new(id: 3, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_4) { EventSourcery::Event.new(id: 4, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_5) { EventSourcery::Event.new(id: 5, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_6) { EventSourcery::Event.new(id: 6, type: 'echo_event', aggregate_id: aggregate_id, body: event_3.body.merge(driven_by_event_payload_key => 3)) }
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
      let(:reactor_class) {
        Class.new do
          include EventSourcery::Postgres::Reactor

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
        reactor.setup
        stub_const("TestActioner", action_stub_class)
      end

      def event_count
        event_source.get_next_from(0, limit: 100).count
      end

      def latest_events(n = 1)
        event_source.get_next_from(0, limit: 100)[-n..-1]
      end

      context "when the event emitted doesn't take actions" do
        let(:reactor_class) {
          Class.new do
            include EventSourcery::Postgres::Reactor

            processes_events :terms_accepted
            emits_events :echo_event

            def process(event)
              emit_event(EventSourcery::Event.new(aggregate_id: event.aggregate_id, type: 'echo_event', body: event.body))
            end
          end
        }

        it 'processes the events as usual' do
          [event_1, event_2, event_3, event_4, event_5].each do |event|
            reactor.process(event)
          end
          expect(event_count).to eq 8
        end
      end

      context "when the event emitted hasn't been defined in emit_events" do
        let(:reactor_class) {
          Class.new do
            include EventSourcery::Postgres::Reactor

            processes_events :terms_accepted
            emits_events :echo_event

            def process(event)
              emit_event(EventSourcery::Event.new(aggregate_id: event.aggregate_id, type: 'echo_event_2', body: event.body))
            end
          end
        }

        it 'raises an error' do
          expect {
            reactor.process(event_1)
          }.to raise_error(EventSourcery::Postgres::Reactor::UndeclaredEventEmissionError)
        end
      end

      context 'when body is yielded to the emit block' do
        let(:events) { [] }
        let(:reactor_class) {
          Class.new do
            include EventSourcery::Postgres::Reactor

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
          reactor.process(event_1)
          expect(latest_events(1).first.body["token"]).to eq 'secret-identifier'
        end

        it 'stores the driven by event id in the body' do
          reactor.process(event_1)
          expect(latest_events(1).first.body["_driven_by_event_id"]).to eq event_1.id
        end
      end

      describe 'already actioned' do
        let(:event_1) { ItemAdded.new(id: 1, aggregate_id: '00000000-0000-0000-0000-000000000001', version: 1) }
        let(:event_3) { ItemAdded.new(id: 3, aggregate_id: '00000000-0000-0000-0000-000000000002', version: 2) }

        let(:events_table_name) { :events_without_optimistic_locking }
        let(:event_store) { EventSourcery::Postgres::EventStore.new(pg_connection, events_table_name: events_table_name) }
        let(:tracker) { EventSourcery::Postgres::Tracker.new(pg_connection, events_table_name: events_table_name) }
        let(:causation_id_metadata_key) { EventSourcery::Postgres::Reactor::CAUSATION_ID_METADATA_KEY }
        let(:reactor_name_metadata_key) { EventSourcery::Postgres::Reactor::REACTOR_NAME_METADATA_KEY }

        let(:reactor_class) {
          Class.new do
            include EventSourcery::Postgres::Reactor

            processor_name :test_processor
            processes_events ItemAdded
            emits_events ItemRemoved.type

            process ItemAdded do |event|
              emit_event ItemRemoved.new(aggregate_id: event.aggregate_id)
            end
          end
        }

        it 'does not re-emit previously actioned events' do
          # Add first event that will be reacted to
          event_store.sink event_1

          # Run through all events
          catch_up_esp(reactor)

          expect(events).to eq [
            [1, {}, {}],
            [2, {driven_by_event_payload_key.to_s => 1}, {causation_id_metadata_key.to_s => 1, reactor_name_metadata_key.to_s => 'test_processor'}],
          ]

          # Add another event that will be reacted to
          event_store.sink event_3

          # Set the last_processed_event_id back to 0
          # The last_actioned_event_id will still be 1
          reactor.reset

          # Re-run through all events
          catch_up_esp(reactor)

          expect(events).to eq [
            [1, {}, {}],
            [2, {driven_by_event_payload_key.to_s => 1}, {causation_id_metadata_key.to_s => 1, reactor_name_metadata_key.to_s => 'test_processor'}],
            [3, {}, {}],
            [4, {driven_by_event_payload_key.to_s => 3}, {causation_id_metadata_key.to_s => 3, reactor_name_metadata_key.to_s => 'test_processor'}],
          ]
        end

        context 'when the last_actioned_event_id is not found' do
          it 'does not re-emit previously actioned events' do
            # Add first event that will be reacted to
            event_store.sink event_1

            # Run through all events
            catch_up_esp(reactor)

            expect(events).to eq [
              [1, {}, {}],
              [2, {driven_by_event_payload_key.to_s => 1}, {causation_id_metadata_key.to_s => 1, reactor_name_metadata_key.to_s => 'test_processor'}],
            ]

            # Add another event that will be reacted to
            event_store.sink event_3

            # Set last_processed_event_id and last_actioned_event_id back to 0
            reactor.reset
            tracker.set_last_actioned_event_id('test_processor', 0)

            # Re-run through all events
            catch_up_esp(reactor)

            expect(events).to eq [
              [1, {}, {}],
              [2, {driven_by_event_payload_key.to_s => 1}, {causation_id_metadata_key.to_s => 1, reactor_name_metadata_key.to_s => 'test_processor'}],
              [3, {}, {}],
              [4, {driven_by_event_payload_key.to_s => 3}, {causation_id_metadata_key.to_s => 3, reactor_name_metadata_key.to_s => 'test_processor'}],
            ]
          end
        end

        def events
          latest_events(0).map do |event|
            [
              event.id,
              event.body.to_h,
              event.metadata.to_h,
            ]
          end
        end

        def catch_up_esp(esp)
          latest_event_id = event_store.latest_event_id
          events = []
          esp.setup
          event_store.each_by_range(esp.last_processed_event_id + 1, latest_event_id) do |event|
            events << event
          end
          esp.send(:process_events, events, EventSourcery::EventStore::SignalHandlingSubscriptionMaster.new) if events.any?
        end
      end

      it 'adds methods to emit permitted events' do
        allow(reactor).to receive(:emit_event).with(type: 'echo_event', aggregate_id: 123, body: { a: :b })
        reactor.emit_echo_event(123, { a: :b })
      end
    end
  end
end
