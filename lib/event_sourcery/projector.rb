module EventSourcery
  module Projector
    def self.included(base)
      base.include(EventHandler)
      base.prepend(TableOwner)
      base.prepend(HandleMethod)
    end

    module HandleMethod
      def handle(event)
        tracker.processing_event(self.class.handler_name, event.id) do
          if self.class.handles?(event.type)
            super(event)
          end
        end
      end
    end

    def initialize(tracker:, db_connection:)
      @tracker = tracker
      @db_connection = db_connection
    end
  end
end
