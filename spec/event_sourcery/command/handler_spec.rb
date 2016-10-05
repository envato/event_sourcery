RSpec.describe EventSourcery::Command::Handler do
  let(:command) { double }
  let(:handler_class) {
    Class.new do
      include EventSourcery::Command::Handler

      def handle(command)
        @command = command
        true
      end
      attr_reader :event_source, :event_sink, :command
    end
  }
  subject(:handler) { handler_class.handle(command) }

  context 'when no event source and sink is provided' do
    before do
      allow(EventSourcery.config).to receive(:event_source).and_return('event_source')
      allow(EventSourcery.config).to receive(:event_sink).and_return('event_sink')
    end

    it 'initializes with default config event stores' do
      expect(handler.event_source).to eq 'event_source'
      expect(handler.event_sink).to eq 'event_sink'
    end
  end

  it 'allows overriding with other stores' do
    handler = handler_class.handle(command, 'source', 'sink')
    expect(handler.event_source).to eq 'source'
    expect(handler.event_sink).to eq 'sink'
  end

  it 'is passed the command' do
    expect(handler.command).to eq command
  end
end
