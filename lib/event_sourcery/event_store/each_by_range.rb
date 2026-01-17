# frozen_string_literal: true

module EventSourcery
  module EventStore
    # Provides iteration over events within a specified range.
    module EachByRange
      def each_by_range(from_event_id, to_event_id, event_types: nil)
        caught_up = false
        no_events_left = false
        event_id = from_event_id
        loop do
          events = get_next_from(event_id, event_types: event_types)
          no_events_left = true if events.empty?
          events.each do |event|
            yield event
            if event.id == to_event_id
              caught_up = true
              break
            end
          end
          event_id = events.last.id + 1 unless no_events_left
          break if caught_up || no_events_left
        end
      end
    end
  end
end
