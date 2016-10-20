RSpec.describe EventSourcery::EventProcessing::EventDispatcher do
  subject(:dispatcher) { described_class.new(event_processors: event_processors, event_store: event_store) }
  let(:event_store) { double(:event_store) }
  let(:event_processors) { [projector, reactor] }

  let(:projector) do
    double(:projector,
           processor_name: 'AccountBalanceProjector',
           setup: true,
           process_events: true,
           last_processed_event_id: projector_last_event_id,
           processes_event_types: projector_event_types)
  end
  let(:projector_last_event_id) { 2 }
  let(:projector_event_types) { [:account_created, :credit, :debit]}

  let(:reactor) do
    double(:reactor,
           processor_name: 'AccountCreationProcessor',
           setup: true,
           process_events: true,
           last_processed_event_id: reactor_last_event_id,
           processes_event_types: reactor_event_types)
  end
  let(:reactor_last_event_id) { 4 }
  let(:reactor_event_types) { [:account_closed, :account_created]}

  describe 'start!' do
    subject(:start!) { dispatcher.start! }
    let(:events) { [event_3, event_4, event_5, event_6] }
    let(:event_3) { double(:event, id: 3) }
    let(:event_4) { double(:event, id: 4) }
    let(:event_5) { double(:event, id: 5) }
    let(:event_6) { double(:event, id: 6) }

    before do
      allow(event_store).to receive(:subscribe).and_yield(events)
    end

    it 'sets up processors' do
      start!
      expect(projector).to have_received(:setup)
      expect(reactor).to have_received(:setup)
    end

    it "subscribes to events with union types of all processors and id greater than smallest last_processed_event_id of all processors" do
      start!
      expect(event_store).to have_received(:subscribe).with(from_id: projector_last_event_id, event_types: [:account_created, :credit, :debit, :account_closed], after_listen: nil)
    end

    it 'projector processes events after last processed one' do
      start!
      expect(projector).to have_received(:process_events).with([event_3, event_4, event_5, event_6])
    end

    it 'reactor processes events' do
      start!
      expect(reactor).to have_received(:process_events).with([event_5, event_6])
    end

    context 'when on_events_processed is set' do
      let(:logger) { double(log: true) }
      before do
        dispatcher.on_events_processed do |processor_name, last_event_id|
          logger.log("Processor #{processor_name} has processed up to event #{last_event_id}")
        end
      end

      it 'calls on_events_processed block when a processor has processed a batch of subscribed events' do
        start!
        expect(logger).to have_received(:log).with("Processor AccountBalanceProjector has processed up to event 6")
        expect(logger).to have_received(:log).with("Processor AccountCreationProcessor has processed up to event 6")
      end
    end
  end
end
