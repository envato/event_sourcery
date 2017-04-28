require 'securerandom'

module EventHelpers
  def new_event(aggregate_id: SecureRandom.uuid, type: 'test_event', body: {}, id: nil, version: 1, created_at: nil, uuid: SecureRandom.uuid)
    EventSourcery::Event.new(id: id,
                             aggregate_id: aggregate_id,
                             type: type,
                             body: body,
                             version: version,
                             created_at: created_at,
                             uuid: uuid)
  end
end

RSpec.configure do |config|
  config.include EventHelpers
end
