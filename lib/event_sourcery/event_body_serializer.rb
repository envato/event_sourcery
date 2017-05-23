module EventSourcery
  class EventBodySerializer
    def self.serialize(event_body,
                       serializer: EventSourcery.config.event_body_serializer)
      serializer.serialize(event_body)
    end

    def initialize
      @serializers = Hash.new(IdentitySerializer)
    end

    def add(type, serializer = nil, &block_serializer)
      @serializers[type] = serializer || block_serializer
      self
    end

    def serialize(object)
      serializer = @serializers[object.class]
      serializer.call(object, &method(:serialize))
    end

    module HashSerializer
      def self.call(hash, &serialize)
        hash.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = serialize.call(value)
        end
      end
    end

    module ArraySerializer
      def self.call(array, &serialize)
        array.map(&serialize)
      end
    end

    module IdentitySerializer
      def self.call(object)
        object
      end
    end
  end
end
