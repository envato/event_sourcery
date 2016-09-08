module EventSourcery
  module Domain
    class Repository
      def self.load(aggregate_class, aggregate_id, event_source, event_sink)
        events = event_source.get_events_for_aggregate_id(aggregate_id)
        aggregate_class.new(aggregate_id, event_sink).tap do |aggregate|
          aggregate.load_history(events)
        end
      end
    end
  end
end
