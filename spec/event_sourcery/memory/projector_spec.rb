RSpec.describe EventSourcery::Memory::Projector do
  let(:projector_class) do
    Class.new do
      include EventSourcery::Memory::Projector
    end
  end

  let(:tracker) { EventSourcery::Memory::Tracker.new }

  subject(:projector) do
    projector_class.new(
      tracker: tracker
    )
  end

  describe '.new' do
    let(:event_tracker) { double }

    before do
      allow(EventSourcery::Memory::Tracker).to receive(:new).and_return(event_tracker)
    end

    subject(:projector) { projector_class.new }

    it 'uses the inferred event tracker by default' do
      expect(projector.instance_variable_get('@tracker')).to eq event_tracker
    end
  end

end
