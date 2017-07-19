RSpec.describe EventSourcery::EventStore::EventSink do
  let(:event_store) { double(:event_store, sink: nil) }
  subject(:event_sink) { described_class.new(event_store) }

  let(:valid_event_1) { double(EventSourcery::Event, valid?: true) }
  let(:valid_event_2) { double(EventSourcery::Event, valid?: true) }
  let(:invalid_event) { double(EventSourcery::Event, valid?: false, validation_errors: {one: 'this event is invalid'}) }

  describe '#sink' do
    context 'when the events are in an array' do
      context 'and all events are valid' do
        let(:events) { [valid_event_1, valid_event_2] }

        it 'validates all events in the array' do
          event_sink.sink(events, expected_version: 3)
          expect(valid_event_1).to have_received(:valid?)
          expect(valid_event_2).to have_received(:valid?)
        end

        it 'passes the array and the expected version to the event store' do
          event_sink.sink(events, expected_version: 3)
          expect(event_store).to have_received(:sink).with(events, expected_version: 3)
        end
      end

      context 'and the last event is invalid' do
        let(:events) { [valid_event_1, invalid_event] }

        it 'validates all events in the array' do
          begin
          event_sink.sink(events)
          rescue
          end
          expect(valid_event_1).to have_received(:valid?)
          expect(invalid_event).to have_received(:valid?)
        end

        it 'does not pass the array to the event store' do
          begin
            event_sink.sink(events)
          rescue
          end
          expect(event_store).not_to have_received(:sink)
        end

        it 'raises an InvalidEventError' do
          expect{ event_sink.sink(events) }.to raise_error EventSourcery::InvalidEventError, /this event is invalid/
        end
      end
    end

    context 'when the event is passed in by itself' do
      context 'and the event is valid' do
        it 'validates the event' do
          event_sink.sink(valid_event_1)
          expect(valid_event_1).to have_received(:valid?)
        end

        it 'wraps the event in an array and passes it to the event store' do
          event_sink.sink(valid_event_1)
          expect(event_store).to have_received(:sink).with([valid_event_1], expected_version: nil)
        end
      end
    end

    context 'and the event is invalid' do
      it 'validates the event' do
        begin
          event_sink.sink(invalid_event)
        rescue
        end
        expect(invalid_event).to have_received(:valid?)
      end

      it 'does not pass the event to the event store' do
        begin
          event_sink.sink(invalid_event)
        rescue
        end
        expect(event_store).not_to have_received(:sink)
      end

      it 'raises an InvalidEvent exception' do
        expect{ event_sink.sink(invalid_event) }.to raise_error EventSourcery::InvalidEventError, /this event is invalid/
      end
    end
  end
end
