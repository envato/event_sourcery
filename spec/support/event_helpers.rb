module EventHelpers
  def new_event(aggregate_id: SecureRandom.uuid, type: 'test_event', body: {}, id: nil)
    EventSourcery::Event.new(id: id,
                             aggregate_id: aggregate_id,
                             type: type,
                             body: body)
  end
end

RSpec.configure do |config|
  config.include EventHelpers
end
