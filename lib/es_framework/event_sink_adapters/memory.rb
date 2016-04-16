module ESFramework
  module EventSinkAdapters
    class Memory
      def initialize(events = [])
        @events = events
      end

      def sink(aggregate_id:, type:, body:)
        id = @events.size + 1
        @events << ESFramework::Event.new(
          id: id,
          aggregate_id: aggregate_id,
          type: type,
          body: body,
          created_at: Time.now
        )
        true
      end
    end
  end
end
