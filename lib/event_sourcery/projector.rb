module EventSourcery
  module Projector
    def self.included(base)
      base.include(EventHandler)
      base.prepend(TableOwner)
      base.prepend(HandleMethod)
    end

    module HandleMethod
      def handle(event)
        if self.class.handles?(event.type)
          super(event)
        end
      end
    end

    def initialize(db_connection:)
      @db_connection = db_connection
    end
  end
end
