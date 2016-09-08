RSpec.describe EventSourcery::EventProcessing::EventStreamProcessor do
  let(:tracker) { EventSourcery::EventProcessing::EventTrackers::Memory.new }

  def new_event_processor(&block)
    Class.new do
      include EventSourcery::EventProcessing::EventStreamProcessor
      instance_eval(&block) if block_given?

      attr_reader :events

      def process(event)
        @events ||= []
        @events << event
      end
    end.new(tracker: tracker)
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
    let(:events) { [new_event, new_event] }
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
  end
end
