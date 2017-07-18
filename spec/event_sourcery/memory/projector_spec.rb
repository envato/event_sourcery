RSpec.describe EventSourcery::Memory::Projector do
  let(:projector_class) do
    Class.new do
      include EventSourcery::Memory::Projector
      processor_name 'test_processor'
    end
  end

  let(:tracker) { EventSourcery::Memory::Tracker.new }

  subject(:projector) do
    projector_class.new(
      tracker: tracker
    )
  end

  def new_projector(&block)
    Class.new do
      include EventSourcery::Memory::Projector
      projector_name 'test_processor'
      processes_events :terms_accepted
      class_eval(&block) if block_given?
      attr_reader :processed_event
    end.new(tracker: tracker)
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

  describe '.projector_name' do
    it 'delegates to processor_name' do
      expect(projector_class.projector_name).to eq 'test_processor'
    end
  end

  describe '#project' do
    let(:event) { new_event(type: :terms_accepted) }

    it 'processes events via project method' do
      projector = new_projector do
        def project(event)
          @processed_event = event
        end
      end
      projector.project(event)
      expect(projector.processed_event).to eq(event)
    end

    it 'processes events with custom classes' do
      projector = new_projector do
        project ItemAdded do |event|
          @processed_event = event
        end
      end
      event = ItemAdded.new
      projector.project(event)
      expect(projector.processed_event).to eq(event)
    end

    it 'raises if neither are defined' do
      projector = new_projector
      expect {
        projector.project(event)
      }.to raise_error(EventSourcery::EventProcessingError)
    end
  end

end
