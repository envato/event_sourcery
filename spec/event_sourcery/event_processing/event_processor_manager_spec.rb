RSpec.describe EventSourcery::EventProcessing::EventProcessorManager do
  subject(:manager) { described_class.new(tracker: tracker, event_processors: [processor_1, processor_2], event_store: event_store) }
  let(:event_store) { EventSourcery::EventStore::Postgres::Connection.new(pg_connection) }
  let(:tracker) { EventSourcery::EventProcessing::EventTrackers::Postgres.new(pg_connection, obtain_processor_lock: false) }

  let(:processor_class) do
    Class.new do
      include EventSourcery::EventProcessing::EventProcessor

      def initialize
        @events = []
      end

      processes_all_events

      def process(event)
        @events << event
      end

      attr_reader :events
    end
  end

  let(:processor_1) { processor_class.dup.new.tap {|p| p.class.processor_name = :processor_1 } }
  let(:processor_2) { processor_class.dup.new.tap {|p| p.class.processor_name = :processor_2 } }
  let(:events) { [new_event(id: 1, type: 'item_added'), new_event(id: 2, type: 'item_added'), new_event(id: 3, type: 'item_removed')] }

  before do
    manager.setup_processors_and_trackers
    tracker.processed_event(processor_1.class.processor_name, 1)
    tracker.processed_event(processor_2.class.processor_name, 2)
  end

  describe '#start!' do
    let(:event_store) { double }

    it 'subscribes from the lowest event ID' do
      expect(event_store).to receive(:subscribe).with(from_id: 1, event_types: nil, after_listen: nil).and_yield([new_event(id: 2)])
      manager.start!
    end

    it 'sends events to process_events' do
      allow(event_store).to receive(:subscribe).with(from_id: 1, event_types: nil, after_listen: nil).and_yield([new_event(id: 3)])
      manager.start!
      expect(processor_1.events.count).to eq 1
      expect(processor_2.events.count).to eq 1
    end

    context 'with event types' do
      before do
        processor_1.class.processes_events :item_added, :item_removed
      end

      it 'subscribes to the combined event types of the processors' do
        expect(event_store).to receive(:subscribe).with(from_id: 1, event_types: %w[item_added item_removed], after_listen: nil).and_yield([new_event(id: 2)])
        manager.start!
      end
    end
  end

  describe '#process_events' do
    it 'sends unseed events to each processor' do
      manager.process_events(events)
      expect(processor_1.events.count).to eq 2
      expect(processor_2.events.count).to eq 1
    end

    it 'updates the tracker for each processor' do
      manager.process_events(events)
      expect(tracker.last_processed_event_id(processor_1.class.processor_name)).to eq 3
      expect(tracker.last_processed_event_id(processor_2.class.processor_name)).to eq 3
    end

    context 'with an events callback hook' do
      before do
        @processed = {}
        manager.on_events_processed do |processor_name, up_to_event_id|
          @processed[processor_name] = up_to_event_id
        end
      end

      it do
        manager.process_events(events)
        expect(@processed[:processor_1]).to eq 3
        expect(@processed[:processor_2]).to eq 3
      end
    end

    context 'with processors that have batch processing disabled' do
      before do
        processor_1.class.disable_batch_processing!
        processor_2.class.disable_batch_processing!
      end

      it 'wraps the tracker around each event being processed' do
        expect(tracker).to receive(:processing_event).exactly(6).times.and_yield
        manager.process_events(events)
      end
    end

    context 'when an error occurs in batch processing' do
      before do
        allow(processor_1).to receive(:process).and_raise(StandardError)
      end

      it "raises an error and doesn't update the track entry" do
        expect(tracker.last_processed_event_id(processor_1.class.processor_name)).to eq 1
        expect {
          manager.process_events(events)
        }.to raise_error(StandardError)
        expect(tracker.last_processed_event_id(processor_1.class.processor_name)).to eq 1
      end
    end
  end
end
