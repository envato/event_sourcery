module EventSourcery
  module EventProcessing
    class EventStreamProcessorRegistry
      def initialize
        @processors = []
      end

      # Register the class of the Event Stream Processor.
      #
      # @param klass [Class] the class to register
      def register(klass)
        @processors << klass
      end

      # Find a registered processor by it's name.
      #
      # @param processor_name [String] name of the processor you're looking for
      #
      # @return [ESProcess, nil] the found processor object or nil
      def find(processor_name)
        @processors.find do |processor|
          processor.processor_name == processor_name
        end
      end

      # Find a registered processor by its type.
      #
      # @param constant [String] name of the constant the processer has included
      #
      # @return [ESProcess, nil] the found processor object or nil
      def by_type(constant)
        @processors.select do |processor|
          processor.included_modules.include?(constant)
        end
      end

      # Returns an array of all the registered processors.
      #
      # @return [Array] of all the processors that are registered
      def all
        @processors
      end
    end
  end
end
