RSpec.describe EventSourcery::EventStore::UpcasterChain do
  subject(:upcaster_chain) { described_class.new }

  before do
    upcaster_chain.define('ItemAdded', 'default currency is USD') do |body|
      body['currency'] ||= 'USD'
    end
  end

  it 'applies transformations for a given class' do
    upcasted_body = upcaster_chain.upcast('ItemAdded', { 'name' => 'Bug' })
    expect(upcasted_body).to eq('name' => 'Bug', 'currency' => 'USD')
  end

  it 'does nothing if none are defined' do
    upcasted_body = upcaster_chain.upcast('ItemRemoved', { 'name' => 'Bug' })
    expect(upcasted_body).to eq('name' => 'Bug')
  end

  context 'with more than one upcaster function' do
    before do
      upcaster_chain.define('ItemAdded') do |body|
        body['currency'] ||= 'AUD'
        body['upcaster_2'] = 'check'
      end
    end

    it 'runs them in order' do
      upcasted_body = upcaster_chain.upcast('ItemAdded', { 'name' => 'Bug' })
      expect(upcasted_body).to eq('name' => 'Bug', 'currency' => 'USD', 'upcaster_2' => 'check')
    end
  end
end
