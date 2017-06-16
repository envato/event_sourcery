RSpec.describe EventSourcery::EventProcessing::EventStreamProcessor do
  let(:tracker) { EventSourcery::Memory::Tracker.new }

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
    expect(registry.find('test')).to eq esp
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

  describe '#reset' do
    subject(:event_processor) {
      new_event_processor do
        processor_name 'my_processor'
        processes_all_events
      end
    }

    before do
      event_processor.setup
      event_processor.process(new_event(id: 1))
    end

    it 'resets last processed event ID' do
      event_processor.reset
      expect(tracker.last_processed_event_id(:test_processor)).to eq 0
    end
  end

  describe '#subscribe_to' do
    let(:event_store) { double(:event_store) }
    let(:events) { [new_event(id: 1), new_event(id: 2)] }
    let(:subscription_master) { spy(EventSourcery::EventStore::SignalHandlingSubscriptionMaster) }
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
                                                      event_types: nil,
                                                      subscription_master: subscription_master)
      event_processor.subscribe_to(event_store, subscription_master: subscription_master)
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
                                                        event_types: ['item_added'],
                                                        subscription_master: subscription_master)
        event_processor.subscribe_to(event_store, subscription_master: subscription_master)
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

    it 'marks the safe shutdown points' do
      event_processor.subscribe_to(event_store, subscription_master: subscription_master)
      expect(subscription_master).to have_received(:shutdown_if_requested).twice
    end
  end

  describe '#process' do
    context 'using a generic process handler' do
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
    end

    context 'when using specific event handlers' do
      def new_esp(&block)
        Class.new do
          include EventSourcery::EventProcessing::EventStreamProcessor
          processor_name 'my_processor'

          class_eval(&block)
        end.new(tracker: tracker)
      end

      subject(:event_processor) {
        new_esp do
          process ItemAdded do |event|
            @added_event = event
          end

          process ItemRemoved do |event|
            @removed_event = event
          end

          attr_reader :added_event, :removed_event
        end
      }
      let(:item_added_event) { ItemAdded.new }
      let(:item_removed_event) { ItemRemoved.new }

      it 'calls the defined handler' do
        event_processor.process(item_added_event)
        expect(event_processor.added_event).to eq item_added_event
        event_processor.process(item_removed_event)
        expect(event_processor.removed_event).to eq item_removed_event
      end

      it 'returns the events in processed event types' do
        expect(event_processor.class.processes_event_types).to eq(['item_added', 'item_removed'])
      end

      context 'processing multiple events in handlers' do
        let(:event_processor) {
          new_esp do
            process ItemAdded do |event|
              @added_event = event
            end

            process ItemAdded, ItemRemoved do |event|
              @added_and_removed_events ||= []
              @added_and_removed_events << event
            end

            attr_reader :added_and_removed_events, :added_event
          end
        }

        it 'calls the associated handlers for each event' do
          event_processor.process(item_added_event)
          event_processor.process(item_removed_event)
          expect(event_processor.added_event).to eq item_added_event
          expect(event_processor.added_and_removed_events).to eq [item_added_event, item_removed_event]
        end
      end

      context 'processing events and raise error' do
        let(:event_processor) {
          new_esp do
            process ItemAdded do |event|
              raise 'Something is wrong'
            end
          end
        }

        it 'wraps raised exception with EventProcessingError' do
          expect {
            event_processor.process(item_added_event)
          }.to raise_error { |error|
            expect(error).to be_a(EventSourcery::EventProcessingError)
            expect(error.event).to eq item_added_event
            expect(error.cause.message).to eq 'Something is wrong'
          }
        end
      end
    end
  end
end
