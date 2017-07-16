module EventSourcery
  module Memory
    module Projector

      def self.included(base)
        base.include(EventSourcery::EventProcessing::EventStreamProcessor)
        base.include(InstanceMethods)
      end

      module InstanceMethods
        def initialize(tracker: EventSourcery::Memory.config.event_tracker)
          @tracker = tracker
        end
      end
    end
  end
end
