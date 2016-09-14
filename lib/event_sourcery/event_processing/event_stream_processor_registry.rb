module EventSourcery
  module EventProcessing
    class EventStreamProcessorRegistry
      def initialize
        @processors = []
      end

      def register(klass)
        @processors << klass
      end

      def find(processor_name)
        @processors.find do |processor|
          processor.processor_name == processor_name
        end
      end

      def projectors
        @processors.select do |processor|
          processor.included_modules.include?(EventSourcery::EventProcessing::Projector)
        end
      end

      def event_reactors
        @processors.select do |processor|
          processor.included_modules.include?(EventSourcery::EventProcessing::EventReactor)
        end
      end

      def all
        @processors
      end
    end
  end
end
