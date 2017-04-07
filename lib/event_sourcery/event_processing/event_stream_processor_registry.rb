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
          processor.included_modules.include?(EventSourcery::Postgres::Projector)
        end
      end

      def reactors
        @processors.select do |processor|
          processor.included_modules.include?(EventSourcery::Postgres::Reactor)
        end
      end

      def all
        @processors
      end
    end
  end
end
