module EventSourcery
  module EventStore
    class UpcasterChain
      class Transformation < Struct.new(:event_type, :description, :function)
      end

      def initialize
        @transformations = Hash.new do |h, k|
          h[k] = []
        end
      end

      def define(event_class_or_type, description = nil, &block)
        event_type = event_type_string(event_class_or_type)
        transformation = Transformation.new(event_type, description, block)
        @transformations[event_type] << transformation
      end

      def upcast(event_class_or_type, body)
        event_type = event_type_string(event_class_or_type)
        transformations[event_type].inject(body) do |body, transformation|
          transformation.function.call(body)
          body
        end
      end

      private

      def event_type_string(event_class_or_type)
        if String === event_class_or_type
          event_class_or_type
        else
          event_class_or_type.type
        end
      end

      attr_reader :transformations
    end
  end
end
