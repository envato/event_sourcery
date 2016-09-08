module EventSourcery
  module EventProcessing
    module Projector
      def self.included(base)
        base.include(EventProcessor)
        base.prepend(TableOwner)
        base.prepend(ProcessHandler)
      end

      def initialize(tracker:, db_connection:)
        @tracker = tracker
        @db_connection = db_connection
      end

      module ProcessHandler
        def process(event)
          tracker.processing_event(processor_name, event.id) do
            if self.class.processes?(event.type)
              super(event)
            end
          end
        end
      end
    end
  end
end
