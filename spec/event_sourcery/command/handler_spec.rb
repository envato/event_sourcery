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

  before do
    allow(EventSourcery.config).to receive(:event_source).and_return(1)
    allow(EventSourcery.config).to receive(:event_sink).and_return(2)
  end

  it 'initializes with default config event stores' do
    expect(handler.event_source).to eq 1
    expect(handler.event_sink).to eq 2
  end

  it 'allows overriding with other stores' do
    handler = handler_class.handle(command, 3, 4)
    expect(handler.event_source).to eq 3
    expect(handler.event_sink).to eq 4
  end

  it 'is passed the command' do
    expect(handler.command).to eq command
  end
end
