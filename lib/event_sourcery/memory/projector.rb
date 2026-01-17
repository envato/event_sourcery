# frozen_string_literal: true

module EventSourcery
  module Memory
    # Provides projection functionality for in-memory event processing.
    module Projector
      def self.included(base)
        base.include(EventSourcery::EventProcessing::EventStreamProcessor)
        base.include(InstanceMethods)
        base.class_eval do
          alias_method :project, :process
          class << self
            alias_method :project, :process
            alias_method :projector_name, :processor_name
          end
        end
      end

      # Instance methods for in-memory projectors.
      module InstanceMethods
        def initialize(tracker: EventSourcery::Memory.config.event_tracker)
          @tracker = tracker
        end
      end
    end
  end
end
