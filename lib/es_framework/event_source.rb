module ESFramework
  class EventSource
    def initialize(adapter)
      @adapter = adapter
    end

    extend Forwardable
    def_delegators :adapter,
                   :get_next_from,
                   :latest_event_id,
                   :get_events_for_aggregate_id

    def each_by_range(from_event_id, to_event_id)
      caught_up = false
      no_events_left = false
      event_id = from_event_id
      begin
        events = get_next_from(event_id)
        no_events_left = true if events.empty?
        events.each do |event|
          yield event
          if event.id == to_event_id
            caught_up = true
            break
          end
        end
        unless no_events_left
          event_id = events.last.id + 1
        end
      end while !caught_up && !no_events_left
    end

    private

    attr_reader :adapter
  end
end
