require 'spec_helper'

RSpec.describe EventSourcery::EventBodySerializer do
  let(:submitted_by_uuid) { SecureRandom.uuid }
  let(:submitted_at) { Time.now.utc }

  describe '.serialize' do
    subject(:serialize) { described_class.serialize(event_body) }

    context 'when event body contains a Time object' do
      let(:event_body) do
        {
          submitted_by_uuid: submitted_by_uuid,
          submitted_at: submitted_at
        }
      end

      it 'converts the Time object as an ISO8601 string' do
        expected_result = {
          submitted_by_uuid: submitted_by_uuid,
          submitted_at: submitted_at.iso8601
        }

        expect(serialize).to eq(expected_result)
      end
    end

    context 'when event body does not contain a Time object' do
      let(:event_body) do
        {
          submitted_by_uuid: submitted_by_uuid
        }
      end

      it 'does no conversions' do
        expect(serialize).to eq(event_body)
      end
    end

    context 'when event body is has a nested hash' do
      let(:event_body) do
        {
          submitted_at: submitted_at,
          nested: {
            submitted_by_uuid: submitted_by_uuid,
            submitted_at: submitted_at
          }
        }
      end

      it 'serializes and keeps the nested structure' do
        expected_result = {
          submitted_at: submitted_at.iso8601,
          nested: {
            submitted_by_uuid: submitted_by_uuid,
            submitted_at: submitted_at.iso8601
          }
        }

        expect(serialize).to eq(expected_result)
      end
    end

    context 'when event body is a complex data structure with nested arrays and hashes' do
      let(:event_body) do
        {
          submitted_at: submitted_at,
          nested: {
            submitted_by_uuid: submitted_by_uuid,
            submissions: [{submitted_at: submitted_at}, {submitted_at: submitted_at}]
          }
        }
      end

      it 'serializes and keeps the nested structure' do
        expected_result = {
          submitted_at: submitted_at.iso8601,
          nested: {
            submitted_by_uuid: submitted_by_uuid,
            submissions: [{submitted_at: submitted_at.iso8601}, {submitted_at: submitted_at.iso8601}]
          }
        }

        expect(serialize).to eq(expected_result)
      end
    end
  end
end
