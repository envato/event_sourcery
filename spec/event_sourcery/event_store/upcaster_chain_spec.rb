RSpec.describe EventSourcery::EventStore::UpcasterChain do
  subject(:upcaster_chain) { described_class.new }

  context 'when there are upcasters defined' do
    before do
      upcaster_chain.define(ItemAdded, 'default currency is USD') do |body|
        body['currency'] ||= 'USD'
      end
    end

    it 'applies transformations for a given class' do
      upcasted_body = upcaster_chain.upcast(ItemAdded, { 'name' => 'Bug' })
      expect(upcasted_body).to eq('name' => 'Bug', 'currency' => 'USD')
    end

    it 'does nothing if none are defined' do
      upcasted_body = upcaster_chain.upcast(ItemRemoved, { 'name' => 'Bug' })
      expect(upcasted_body).to eq('name' => 'Bug')
    end

    it 'upcasts given the event type string also' do
      upcasted_body = upcaster_chain.upcast('item_added', { 'name' => 'Bug' })
      expect(upcasted_body).to eq('name' => 'Bug', 'currency' => 'USD')
    end

    context 'with more than one upcaster function' do
      before do
        upcaster_chain.define(ItemAdded) do |body|
          body['currency'] ||= 'AUD'
          body['upcaster_2'] = 'check'
        end
      end

      it 'runs them in order' do
        upcasted_body = upcaster_chain.upcast(ItemAdded, { 'name' => 'Bug' })
        expect(upcasted_body).to eq('name' => 'Bug', 'currency' => 'USD', 'upcaster_2' => 'check')
      end
    end
  end

  context 'when there are no upcasters for a given type' do
    it 'returns the body as is' do
      upcasted_body = upcaster_chain.upcast(ItemAdded, { 'name' => 'Bug' })
      expect(upcasted_body).to eq('name' => 'Bug')
    end
  end
end
