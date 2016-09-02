module EventSourcery
  module EventStore
    class EventSource
      def initialize(adapter)
        @adapter = adapter
      end

      extend Forwardable
      def_delegators :adapter,
                     :get_next_from,
                     :latest_event_id,
                     :get_events_for_aggregate_id,
                     :each_by_range

      private

      attr_reader :adapter
    end
  end
end
