module EventSourcery
  module EventProcessing
    module Projector
      def self.included(base)
        base.include(EventStreamProcessor)
        base.prepend(TableOwner)
        base.include(InstanceMethods)
      end

      module InstanceMethods
        def initialize(tracker:, db_connection:)
          @tracker = tracker
          @db_connection = db_connection
        end

        private

        def process_events(events)
          events.each do |event|
            db_connection.transaction do
              process(event)
              tracker.processed_event(processor_name, event.id)
            end
          end
        end
      end
    end
  end
end
