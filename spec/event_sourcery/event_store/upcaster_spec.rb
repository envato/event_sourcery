RSpec.describe EventSourcery::EventStore::Upcaster do
  subject(:upcaster) { described_class.new }

  before do
    upcaster.define('ItemAdded', 'default currency is USB') do |body|
      body['currency'] ||= 'USD'
    end
  end

  it 'applies transformations for a given class' do
    upcasted_body = upcaster.upcast('ItemAdded', { 'name' => 'Bug' })
    expect(upcasted_body).to eq('name' => 'Bug', 'currency' => 'USD')
  end

  it 'does nothing if none are defined' do
    upcasted_body = upcaster.upcast('ItemRemoved', { 'name' => 'Bug' })
    expect(upcasted_body).to eq('name' => 'Bug')
  end
end
