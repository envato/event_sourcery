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

  end
end
