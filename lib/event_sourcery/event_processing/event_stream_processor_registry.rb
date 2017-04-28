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

      def by_type(constant)
        @processors.select do |processor|
          processor.included_modules.include?(constant)
        end
      end

      def all
        @processors
      end
    end
  end
end
