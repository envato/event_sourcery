RSpec.describe EventSourcery::EventSource do
  let(:event_store) { double(:event_store) }
  subject(:event_source) { described_class.new(adapter) }

  describe 'adapter delegations' do
    let(:adapter) { double }

    %w[
      get_next_from
      latest_event_id
      get_events_for_aggregate_id
      each_by_range
    ].each do |method|
      it "delegates ##{method} to the adapter" do
        allow(event_store).to receive(method.to_sym).and_return([])
        result = event_store.send(method.to_sym)
        expect(event_store).to have_received(method.to_sym)
      end
    end
  end
end
