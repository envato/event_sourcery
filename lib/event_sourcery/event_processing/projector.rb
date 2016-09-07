module EventSourcery
  module EventProcessing
    module Projector
      def self.included(base)
        base.include(EventProcessor)
        base.prepend(TableOwner)
      end

      def initialize(db_connection:)
        @db_connection = db_connection
      end
    end
  end
end
