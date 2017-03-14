module EventSourcery
  module EventProcessing
    module Projector
      def self.included(base)
        base.include(EventStreamProcessor)
        base.prepend(TableOwner)
        base.include(InstanceMethods)
        base.class_eval do
          alias project process

          class << self
            alias project process
            alias projects_events processes_events
            alias projector_name processor_name
          end
        end
      end

      module InstanceMethods
        def initialize(tracker: EventSourcery.config.event_tracker, db_connection: EventSourcery.config.projections_database)
          @tracker = tracker
          @db_connection = db_connection
        end

        private

        def process_method_name
          'project'
        end

        def process_events(events, subscription_master)
          events.each do |event|
            subscription_master.mark_safe_shutdown_point
            db_connection.transaction do
              process(event)
              tracker.processed_event(processor_name, event.id)
            end
            EventSourcery.logger.debug { "[#{processor_name}] Processed event: #{event.inspect}" }
            EventSourcery.logger.info { "[#{processor_name}] Processed up to event id: #{events.last.id}" }
          end
        end
      end
    end
  end
end
