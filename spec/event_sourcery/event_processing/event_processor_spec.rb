RSpec.describe EventSourcery::EventProcessing::EventProcessor do
  let(:tracker) { EventSourcery::EventProcessing::EventTrackers::Memory.new }

  def new_event_processor(&block)
    Class.new do
      include EventSourcery::EventProcessing::EventProcessor
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

  describe '#process_events' do
    it 'calls process for each event' do
      event_processor = new_event_processor
      events = [new_event, new_event]
      event_processor.process_events(events)
      expect(event_processor.events).to eq events
    end
  end
end
