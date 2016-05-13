RSpec.describe EventSourcery::DownstreamEventProcessor do
  let(:dep_class) {
    Class.new do
      include EventSourcery::DownstreamEventProcessor

      handles_events :terms_accepted

      def handle(event)
        @processed_event = event
      end

      attr_reader :processed_event
    end
  }
  let(:dep_class_with_emit) {
    Class.new do
      include EventSourcery::DownstreamEventProcessor

      handles_events :terms_accepted
      emits_events :blah

      def handle(event)
      end
    end
  }

  let(:dep_name) { 'my_dep' }
  let(:event_source_adapter) { EventSourcery::EventSourceAdapters::Memory.new(events) }
  let(:event_source) { EventSourcery::EventSource.new(event_source_adapter) }

  let(:event_sink_adapter) { EventSourcery::EventSinkAdapters::Memory.new(events) }
  let(:event_sink) { EventSourcery::EventSink.new(event_sink_adapter) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:events) { [] }
  subject(:dep) { dep_class.new(event_source: event_source, event_sink: event_sink) }

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
        dep_class_with_emit.new(event_source, nil)
      }.to raise_error(ArgumentError)
    end

    it 'requires an event source' do
      expect {
        dep_class_with_emit.new(nil, event_sink)
      }.to raise_error(ArgumentError)
    end
  end

  describe '#setup' do
    context 'a processor that emits events' do
      it 'grabs latest event id from event source' do
        expect(event_source).to receive(:latest_event_id)
        dep_class_with_emit.new(event_source: event_source, event_sink: event_sink).setup
      end
    end
  end

  describe '.handles?' do
    it 'returns true if the event has been defined' do
      expect(dep_class.handles?('terms_accepted')).to eq true
      expect(dep_class.handles?(:terms_accepted)).to eq true
    end

    it "returns false if the event hasn't been defined" do
      expect(dep_class.handles?('item_viewed')).to eq false
      expect(dep_class.handles?(:item_viewed)).to eq false
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
    dep_class.handler_name = 'my_processor'
    expect(dep_class.handler_name).to eq 'my_processor'
  end

  it 'has a default handler_name of the class name' do
    allow(dep_class).to receive(:name).and_return('EventSourcery::EventSource')
    expect(dep_class.handler_name).to eq 'EventSourcery::EventSource'
  end

  describe '#handle' do
    let(:event) { OpenStruct.new(type: :terms_accepted, id: 1) }

    it "projects events it's interested in" do
      dep.handle(event)
      expect(dep.processed_event).to eq(event)
    end

    context "with a type the DownstreamEventProcessor isn't interested in" do
      let(:event) { OpenStruct.new(type: :item_viewed, id: 1) }

      it "doesn't process unexpected events" do
        dep.handle(event)
        expect(dep.processed_event).to eq(nil)
      end
    end

    context 'with a DEP that emits events' do
      let(:event_1) { EventSourcery::Event.new(id: 1, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_2) { EventSourcery::Event.new(id: 2, type: 'echo_event', aggregate_id: aggregate_id, body: event_1.body.merge(EventSourcery::DownstreamEventProcessor::DRIVEN_BY_EVENT_PAYLOAD_KEY => 1)) }
      let(:event_3) { EventSourcery::Event.new(id: 3, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_4) { EventSourcery::Event.new(id: 4, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_5) { EventSourcery::Event.new(id: 5, type: 'terms_accepted', aggregate_id: aggregate_id, body: { time: Time.now }) }
      let(:event_6) { EventSourcery::Event.new(id: 6, type: 'echo_event', aggregate_id: aggregate_id, body: event_3.body.merge(EventSourcery::DownstreamEventProcessor::DRIVEN_BY_EVENT_PAYLOAD_KEY => 3)) }
      let(:events) { [event_1, event_2, event_3, event_4] }

      before do
        dep.setup
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
            include EventSourcery::DownstreamEventProcessor

            handles_events :terms_accepted
            emits_events :echo_event

            def handle(event)
              emit_event(aggregate_id: event.aggregate_id, type: 'echo_event', body: event.body)
            end
          end
        }

        it 'processes the events as usual' do
          [event_1, event_2, event_3, event_4, event_5].each do |event|
            dep.handle(event)
          end
          expect(event_count).to eq 8
        end
      end

      context "when the event emitted hasn't been defined in emit_events" do
        let(:dep_class) {
          Class.new do
            include EventSourcery::DownstreamEventProcessor

            handles_events :terms_accepted
            emits_events :echo_event

            def handle(event)
              emit_event(aggregate_id: event.aggregate_id, type: 'echo_event_2', body: event.body)
            end
          end
        }

        it 'raises an error' do
          expect {
            dep.handle(event_1)
          }.to raise_error(EventSourcery::DownstreamEventProcessor::UndeclaredEventEmissionError)
        end
      end

      context 'when body is yielded to the emit block' do
        let(:dep_class) {
          Class.new do
            include EventSourcery::DownstreamEventProcessor

            handles_events :terms_accepted
            emits_events :echo_event

            def handle(event)
              emit_event(aggregate_id: event.aggregate_id, type: 'echo_event') do |body|
                body[:token] = 'secret-identifier'
              end
            end
          end
        }

        let(:events) { [] }

        it 'can manupulates event body as part of the action' do
          dep.handle(event_1)
          expect(latest_events(1).first.body[:token]).to eq 'secret-identifier'
        end
      end
    end
  end
end
