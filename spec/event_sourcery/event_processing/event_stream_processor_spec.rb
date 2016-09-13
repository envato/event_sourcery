RSpec.describe EventSourcery::EventProcessing::EventStreamProcessor do
  let(:tracker) { EventSourcery::EventProcessing::EventTrackers::Memory.new }

  def new_event_processor(&block)
    Class.new do
      include EventSourcery::EventProcessing::EventStreamProcessor
      attr_reader :events

      def initialize(tracker:)
        super
        @events = []
      end

      def process(event)
        @events << event
      end

      class_eval(&block) if block_given?
    end.new(tracker: tracker)
  end

  it 'registers with the ESP registry' do
    registry = EventSourcery::EventProcessing::EventStreamProcessorRegistry.new
    allow(EventSourcery).to receive(:event_stream_processor_registry).and_return(registry)
    esp = Class.new do
      include EventSourcery::EventProcessing::EventStreamProcessor
      processor_name 'test'
    end
    expect(registry.find('test')).to eq esb
  end

  describe '#processor_name' do
    it 'sets processor name' do
      processor = new_event_processor do
        processor_name 'my_processor'
      end
      expect(processor.class.processor_name).to eq 'my_processor'
      expect(processor.processor_name).to eq 'my_processor'
    end

    it 'defaults to class name' do
      processor = new_event_processor
      expect(processor.class.processor_name).to eq processor.class.name
      expect(processor.processor_name).to eq processor.class.name
    end
  end

  describe '#processes?' do
    it 'returns true for events the processor is interested in' do
      event_processor = new_event_processor do
        processes_events :item_added, :item_removed
      end
      expect(event_processor.processes?(:item_added)).to eq true
      expect(event_processor.processes?('item_added')).to eq true
      expect(event_processor.processes?(:item_removed)).to eq true
      expect(event_processor.processes?('item_removed')).to eq true
      expect(event_processor.processes?(:blah)).to eq false
      expect(event_processor.processes?('blah')).to eq false
    end
  end

  describe '#subscribe_to' do
    let(:event_store) { double(:event_store) }
    let(:events) { [new_event(id: 1), new_event(id: 2)] }
    subject(:event_processor) {
      new_event_processor do
        processor_name 'my_processor'
        processes_all_events
      end
    }

    before do
      allow(event_store).to receive(:subscribe).and_yield(events).once
    end

    it 'sets up the tracker' do
      expect(tracker).to receive(:setup).with('my_processor')
      event_processor.subscribe_to(event_store)
    end

    it 'subscribes to the event store from the last processed ID + 1' do
      allow(tracker).to receive(:last_processed_event_id).with('my_processor').and_return(2)
      expect(event_store).to receive(:subscribe).with(from_id: 3,
                                                      event_types: nil)
      event_processor.subscribe_to(event_store)
    end

    context 'when processing specific event types' do
      subject(:event_processor) {
        new_event_processor do
          processor_name 'my_processor'
          processes_events :item_added
        end
      }

      it 'subscribes to the event store for the given types' do
        allow(tracker).to receive(:last_processed_event_id).with('my_processor').and_return(2)
        expect(event_store).to receive(:subscribe).with(from_id: 3,
                                                        event_types: ['item_added'])
        event_processor.subscribe_to(event_store)
      end
    end

    it 'processes events received on the subscription' do
      event_processor.subscribe_to(event_store)
      expect(event_processor.events).to eq events
    end

    it 'updates the tracker after each event has been processed' do
      expect(tracker).to receive(:processed_event).with(event_processor.processor_name, events[0].id)
      expect(tracker).to receive(:processed_event).with(event_processor.processor_name, events[1].id)
      event_processor.subscribe_to(event_store)
    end
  end

  describe '#process' do
    let(:event) { new_event(type: 'item_added') }
    subject(:event_processor) {
      Class.new do
        include EventSourcery::EventProcessing::EventStreamProcessor
        attr_reader :events
        processor_name 'my_processor'
        processes_events :item_added

        attr_reader :internal_event_ref

        def process(event)
          @internal_event_ref = _event.dup
          @events ||= []
          @events << event
        end
      end.new(tracker: tracker)
    }

    context 'making event available to internals' do
      it 'makes the current event available to the instance' do
        event_processor.process(event)
        expect(event_processor.internal_event_ref).to eq event
      end
    end

    context "given an event the processor doesn't care about" do
      let(:event) { new_event(type: 'item_starred') }

      it 'does not process them' do
        event_processor.process(event)
        expect(event_processor.events).to be_nil
      end
    end

    context 'given an event the processor cares about' do
      let(:event) { new_event(type: 'item_added') }

      it 'processes them' do
        event_processor.process(event)
        expect(event_processor.events).to eq [event]
      end
    end

    context 'event handler methods' do
      context 'when an event handler method exists' do
        subject(:event_processor) {
          new_event_processor do
            processor_name 'my_processor'
            processes_events :item_added

            def process_item_added(event)
              @event = event
            end

            attr_reader :event
          end
        }

        it 'is used to process the event' do
          event_processor.process(event)
          expect(event_processor.event).to eq event
        end
      end

      context 'when the event handler method does not exist' do
        context 'when a generic process method is defined' do
          subject(:event_processor) {
            new_event_processor do
              processor_name 'my_processor'
              processes_events :item_added
            end
          }

          it 'is used to process the event' do
            event_processor.process(event)
            expect(event_processor.events).to eq [event]
          end
        end

        context 'and no process method is defined' do
          subject(:event_processor) {
            Class.new do
              include EventSourcery::EventProcessing::EventStreamProcessor
              processor_name 'my_processor'
              processes_events :item_added
            end.new(tracker: tracker)
          }

          it 'is used to process the event' do
            expect {
              event_processor.process(event)
            }.to raise_error(EventSourcery::UnableToProcessEventError)
          end
        end
      end
    end
  end
end
