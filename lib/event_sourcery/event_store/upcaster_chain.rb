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

      def define(event_type, description = nil, &block)
        transformation = Transformation.new(event_type, description, block)
        @transformations[event_type] << transformation
      end

      def upcast(type, body)
        transformations[type].inject(body) do |body, transformation|
          transformation.function.call(body)
          body
        end
      end

      private

      attr_reader :transformations
    end
  end
end
