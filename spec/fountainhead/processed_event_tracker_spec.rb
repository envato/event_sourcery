RSpec.describe Fountainhead::ProcessedEventTracker do
  let(:adapter) { double }
  subject(:processed_event_tracker) { described_class.new(adapter) }

  %w[setup processed_event reset_last_processed_event_id last_processed_event_id tracked_processors processing_event].each do |method|
    it "delegates #{method} to the adapter" do
      expect(adapter).to receive(method)
      processed_event_tracker.send(method)
    end
  end
end
