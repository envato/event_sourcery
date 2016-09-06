module EventSourcery
  module EventProcessing
    module EventProcessor
      def self.included(base)
        base.extend(ClassMethods)
        base.prepend(ProcessHandler)
      end

      module ClassMethods
        def processes_event_types
          @processes_event_types ||= []
        end

        def processes_events(*event_types)
          @processes_event_types = event_types.map(&:to_s)
        end

        def processes_all_events
          define_singleton_method :processes? do |_|
            true
          end
        end

        def processes?(event_type)
          processes_event_types.include?(event_type.to_s)
        end

        def processor_name=(name)
          @processor_name = name
        end

        def processor_name
          @processor_name || self.name
        end

        attr_reader :event_types
      end

      module ProcessHandler
        def process(event)
          @event = event
          if self.class.processes?(event.type)
            super(event)
          end
          @event = nil
        end
      end
    end
  end
end
