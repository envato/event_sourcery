module EventSourcery
  class EventSource
    def initialize(adapter)
      @adapter = adapter
    end

    extend Forwardable
    def_delegators :adapter,
                   :get_next_from,
                   :latest_event_id,
                   :get_events_for_aggregate_id

    def fetch_in_batches(from_event_id, to_event_id, event_types: nil)
      caught_up = false
      no_events_left = false
      event_id = from_event_id
      begin
        events = get_next_from(event_id, event_types: event_types, to: to_event_id)
        no_events_left = true if events.empty?
        yield events
        if !no_events_left && events.last.id == to_event_id
          caught_up = true
          break
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
