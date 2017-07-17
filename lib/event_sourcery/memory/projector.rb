module EventSourcery
  module Memory
    module Projector

      def self.included(base)
        base.include(EventSourcery::EventProcessing::EventStreamProcessor)
        base.include(InstanceMethods)
        base.class_eval do
          class << self
            alias_method :projector_name, :processor_name
          end
        end
      end

      module InstanceMethods
        def initialize(tracker: EventSourcery::Memory.config.event_tracker)
          @tracker = tracker
        end
      end
    end
  end
end
