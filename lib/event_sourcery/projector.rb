module EventSourcery
  module Projector
    def self.included(base)
      base.include(EventProcessor)
      base.prepend(TableOwner)
      base.prepend(ProcessHandler)
    end

    module ProcessHandler
      def process(event)
        if self.class.processes?(event.type)
          super(event)
        end
        tracker.processed_event(self.class.processor_name, event.id)
      end
    end

    def initialize(tracker:, db_connection:)
      @tracker = tracker
      @db_connection = db_connection
    end
  end
end
