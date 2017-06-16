RSpec.describe EventSourcery::Event do
  let(:aggregate_id) { 'aggregate_id' }
  let(:type) { 'type' }
  let(:version) { 1 }
  let(:body) do
    {
      symbol: "value",
    }
  end
  let(:uuid) { SecureRandom.uuid }

  describe '#initialize' do
    subject(:initializer) { described_class.new(aggregate_id: aggregate_id, type: type, body: body, version: version) }

    before do
      allow(EventSourcery::EventBodySerializer).to receive(:serialize)
    end

    it 'serializes event body' do
      expect(EventSourcery::EventBodySerializer).to receive(:serialize).with(body)
      initializer
    end

    it 'assigns a uuid if one is not given' do
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
      expect(initializer.uuid).to eq uuid
    end

    it 'assigns given uuids' do
      uuid = SecureRandom.uuid
      expect(described_class.new(uuid: uuid).uuid).to eq uuid
    end

    it 'assigns a given correlation_id' do
      uuid = SecureRandom.uuid
      event = described_class.new(correlation_id: uuid)
      expect(event.correlation_id).to eq uuid
    end

    it 'has a nil correlation_id if none is given' do
      event = described_class.new
      expect(event.correlation_id).to be_nil
    end

    it 'assigns a given causation_id' do
      uuid = SecureRandom.uuid
      event = described_class.new(causation_id: uuid)
      expect(event.causation_id).to eq uuid
    end

    it 'has a nil causation_id if none is given' do
      event = described_class.new
      expect(event.causation_id).to be_nil
    end

    context 'event body is nil' do
      let(:body) { nil }

      it 'skips serialization of event body' do
        expect(EventSourcery::EventBodySerializer).to_not receive(:serialize)
        initializer
      end
    end

    context 'given version is a long string' do
      let(:version) { '1' * 20 }

      it 'version type is coerced to an integer value, bignum style' do
        expect(initializer.version).to eq(11_111_111_111_111_111_111)
      end
    end
  end

  describe '.type' do
    let(:serializer) { double }

    before do
      allow(EventSourcery.config).to receive(:event_type_serializer).and_return(serializer)
      allow(serializer).to receive(:serialize).and_return('serialized')
    end

    it 'delegates to the configured event type serializer' do
      ItemAdded.type
      expect(serializer).to have_received(:serialize).with(ItemAdded)
    end

    it 'returns the serialized type' do
      expect(ItemAdded.type).to eq('serialized')
    end

    context 'when the event is EventSourcery::Event' do
      it 'returns nil' do
        expect(EventSourcery::Event.type).to be_nil
      end
    end
  end

  describe '#type' do
    before do
      allow(EventSourcery::Event).to receive(:type).and_return(type)
    end

    context 'when the event class type is nil' do
      let(:type) { nil }

      it 'uses the provided type' do
        event = EventSourcery::Event.new(type: 'blah')
        expect(event.type).to eq 'blah'
      end
    end

    context 'when the event class type is not nil' do
      let(:type) { 'ItemAdded' }

      it "can't be overridden with the provided type" do
        event = EventSourcery::Event.new(type: 'blah')
        expect(event.type).to eq 'ItemAdded'
      end
    end
  end

  describe '#with' do
    subject(:with) { original_event.with(**changes) }

    let(:original_event) { EventSourcery::Event.new(**original_attributes) }
    let(:original_attributes) do
      {
        id:             73,
        uuid:           SecureRandom.uuid,
        aggregate_id:   SecureRandom.uuid,
        type:           'type',
        body:           { 'attr' => 'value' },
        version:        89,
        created_at:     Time.now.utc,
        correlation_id: SecureRandom.uuid,
        causation_id:   SecureRandom.uuid,
      }
    end
    let(:changes) do
      {
        causation_id: SecureRandom.uuid,
      }
    end

    it 'returns a new event' do
      expect(with).to_not be(original_event)
    end

    it 'makes the changes to the new event' do
      changes.each do |attribute, value|
        expect(with.send(attribute)).to eq(value)
      end
    end

    it 'maintains the original, unchanged values on the new event' do
      original_attributes.each do |attribute, value|
        expect(with.send(attribute)).to(eq(value)) unless changes.include?(attribute)
      end
    end

    it 'does not mutate the original event' do
      original_attributes.each do |attribute, value|
        expect(original_event.send(attribute)).to(eq(value))
      end
    end
  end

  describe '#to_h' do
    %i[id uuid aggregate_id type body version created_at correlation_id causation_id].each do |attribute|
      it "includes #{attribute}" do
        value = %i[id version].include?(attribute) ? 42 : '42'
        event = EventSourcery::Event.new(attribute => value)
        expect(event.to_h).to include(attribute => value)
      end
    end
  end

  describe '#hash' do
    subject(:hash) { event.hash }

    context 'given an Event with UUID' do
      let(:event) { EventSourcery::Event.new(uuid: event_uuid) }
      let(:event_uuid) { SecureRandom.uuid }

      it { should be_an Integer }

      context 'compared to an Event with same UUID' do
        let(:other) { EventSourcery::Event.new(uuid: event_uuid) }
        it { should eq other.hash }
      end

      context 'compared to an Event with same UUID (uppercase)' do
        let(:other) { EventSourcery::Event.new(uuid: event_uuid.upcase) }
        it { should eq other.hash }
      end

      context 'compared to an event with different UUID' do
        let(:other) { EventSourcery::Event.new(uuid: SecureRandom.uuid) }
        it { should_not eq other.hash }
      end

      context 'compared to an event without UUID' do
        let(:other) { EventSourcery::Event.new(uuid: nil) }
        it { should_not eq other.hash }
      end

      context 'compared to an ItemAdded event with same UUID' do
        let(:other) { ItemAdded.new(uuid: event_uuid) }
        it { should_not eq other.hash }
      end
    end

    context 'given an Event without UUID' do
      let(:event) { EventSourcery::Event.new(uuid: nil) }

      it { should be_an Integer }

      context 'compared to an Event without UUID' do
        let(:other) { EventSourcery::Event.new(uuid: nil) }
        it { should eq other.hash }
      end

      context 'compared to an event with UUID' do
        let(:other) { EventSourcery::Event.new(uuid: SecureRandom.uuid) }
        it { should_not eq other.hash }
      end
    end
  end

  describe '#eql?' do
    subject(:eql?) { event.eql?(other) }

    context 'given an Event with UUID' do
      let(:event) { EventSourcery::Event.new(uuid: event_uuid) }
      let(:event_uuid) { SecureRandom.uuid }

      context 'compared to itself' do
        let(:other) { event }
        it { should be true }
      end

      context 'compared to an Event with same UUID' do
        let(:other) { EventSourcery::Event.new(uuid: event_uuid) }
        it { should be true }
      end

      context 'compared to an Event with same UUID (uppercase)' do
        let(:other) { EventSourcery::Event.new(uuid: event_uuid.upcase) }
        it { should be true }
      end

      context 'compared to an event with different UUID' do
        let(:other) { EventSourcery::Event.new(uuid: SecureRandom.uuid) }
        it { should be false }
      end

      context 'compared to an event without UUID' do
        let(:other) { EventSourcery::Event.new(uuid: nil) }
        it { should be false }
      end

      context 'compared to an ItemAdded event with same UUID' do
        let(:other) { ItemAdded.new(uuid: event_uuid) }
        it { should be false }
      end
    end

    context 'given an Event without UUID' do
      let(:event) { EventSourcery::Event.new(uuid: nil) }

      context 'compared to itself' do
        let(:other) { event }
        it { should be true }
      end

      context 'compared to an Event without UUID' do
        let(:other) { EventSourcery::Event.new(uuid: nil) }
        it { should be true }
      end

      context 'compared to an event with UUID' do
        let(:other) { EventSourcery::Event.new(uuid: SecureRandom.uuid) }
        it { should be false }
      end
    end
  end

  describe '#<' do
    subject(:<) { event < other }

    context 'given an Event with id 2' do
      let(:event) { EventSourcery::Event.new(id: 2) }

      context 'compared to itself' do
        let(:other) { event }
        it { should be false }
      end

      context 'compared to an ItemAdded event with id 1' do
        let(:other) { ItemAdded.new(id: 1) }
        it { should be false }
      end

      context 'compared to an ItemAdded event with id 2' do
        let(:other) { ItemAdded.new(id: 2) }
        it { should be false }
      end

      context 'compared to an ItemAdded event with id 3' do
        let(:other) { ItemAdded.new(id: 3) }
        it { should be true }
      end

      context 'compared to an ItemAdded event without id' do
        let(:other) { ItemAdded.new(id: nil) }

        it 'raises an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context 'compared to a non-event' do
        let(:other) { 3 }

        it 'raises an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe '#<=' do
    subject(:<=) { event <= other }

    context 'given an Event with id 2' do
      let(:event) { EventSourcery::Event.new(id: 2) }

      context 'compared to itself' do
        let(:other) { event }
        it { should be true }
      end

      context 'compared to an ItemAdded event with id 1' do
        let(:other) { ItemAdded.new(id: 1) }
        it { should be false }
      end

      context 'compared to an ItemAdded event with id 2' do
        let(:other) { ItemAdded.new(id: 2) }
        it { should be true }
      end

      context 'compared to an ItemAdded event with id 3' do
        let(:other) { ItemAdded.new(id: 3) }
        it { should be true }
      end

      context 'compared to an ItemAdded event without id' do
        let(:other) { ItemAdded.new(id: nil) }

        it 'raises an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context 'compared to a non-event' do
        let(:other) { 3 }

        it 'raises an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe '#==' do
    subject(:==) { event == other }

    context 'given an Event with id 2' do
      let(:event) { EventSourcery::Event.new(id: 2) }

      context 'compared to itself' do
        let(:other) { event }
        it { should be true }
      end

      context 'compared to an ItemAdded event with id 1' do
        let(:other) { ItemAdded.new(id: 1) }
        it { should be false }
      end

      context 'compared to an ItemAdded event with id 2' do
        let(:other) { ItemAdded.new(id: 2) }
        it { should be true }
      end

      context 'compared to an ItemAdded event with id 3' do
        let(:other) { ItemAdded.new(id: 3) }
        it { should be false }
      end

      context 'compared to a non-event' do
        let(:other) { 3 }
        it { should be false }
      end
    end

    context 'given an Event without id' do
      let(:event) { EventSourcery::Event.new(id: nil) }

      context 'compared to itself' do
        let(:other) { event }
        it { should be true }
      end

      context 'compared to an ItemAdded event without id' do
        let(:other) { ItemAdded.new(id: nil) }
        it { should be true }
      end

      context 'compared to an ItemAdded event with id 1' do
        let(:other) { ItemAdded.new(id: 1) }
        it { should be false }
      end
    end
  end

  describe '#<=' do
    subject(:<=) { event <= other }

    context 'given an ItemRemoved event with id 2' do
      let(:event) { ItemRemoved.new(id: 2) }

      context 'compared to itself' do
        let(:other) { event }
        it { should be true }
      end

      context 'compared to an ItemAdded event with id 1' do
        let(:other) { ItemAdded.new(id: 1) }
        it { should be false }
      end

      context 'compared to an ItemAdded event with id 2' do
        let(:other) { ItemAdded.new(id: 2) }
        it { should be true }
      end

      context 'compared to an ItemAdded event with id 3' do
        let(:other) { ItemAdded.new(id: 3) }
        it { should be true }
      end

      context 'compared to an ItemAdded event without id' do
        let(:other) { ItemAdded.new(id: nil) }

        it 'raises an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context 'compared to a non-event' do
        let(:other) { 3 }

        it 'raises an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe '#<' do
    subject(:<) { event < other }

    context 'given an Event with id 2' do
      let(:event) { EventSourcery::Event.new(id: 2) }

      context 'compared to itself' do
        let(:other) { event }
        it { should be false }
      end

      context 'compared to an ItemAdded event with id 1' do
        let(:other) { ItemAdded.new(id: 1) }
        it { should be false }
      end

      context 'compared to an ItemAdded event with id 2' do
        let(:other) { ItemAdded.new(id: 2) }
        it { should be false }
      end

      context 'compared to an ItemAdded event with id 3' do
        let(:other) { ItemAdded.new(id: 3) }
        it { should be true }
      end

      context 'compared to an ItemAdded event without id' do
        let(:other) { ItemAdded.new(id: nil) }

        it 'raises an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context 'compared to a non-event' do
        let(:other) { 3 }

        it 'raises an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end
  end
end
