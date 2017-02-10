RSpec.describe EventSourcery::EventStore::EventClassResolvers::ClassName do
  subject(:resolver) { described_class.new }

  it 'resolves types to the associated constant' do
    expect(resolver.resolve('ItemAdded')).to eq ItemAdded
  end

  it 'falls back to the generic Event class when one is not found' do
    expect(resolver.resolve('UnknownEventType')).to eq EventSourcery::Event
  end
end
