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
    let(:item_added_event) { ItemAdded.new }
    let(:terms_accepted_event) { TermsAccepted.new }

    it 'processes all events' do
      projector = new_projector do
        attr_reader :events

        project do |event|
          @events ||= []
          @events << event
        end
      end

      projector.project(item_added_event)
      projector.project(terms_accepted_event)

      expect(projector.events).to eq [item_added_event, terms_accepted_event]
    end

    it 'processes specified events' do
      projector = new_projector do
        attr_reader :events

        project ItemAdded do |event|
          @events ||= []
          @events << event
        end
      end

      projector.project(item_added_event)
      projector.project(terms_accepted_event)

      expect(projector.events).to eq [item_added_event]
    end
  end
end
