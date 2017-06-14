module EventSourcery
  # EventBodySerializer is used for serializing event bodies when persisting events. It also contains
  class EventBodySerializer
    # Serialize the given event body, with the default or the provided, serializer
    #
    # @param event_body event body to be serialized
    # @param serializer Optional. Serializer to be used. By default {Config#event_body_serializer EventSourcery.config.event_body_serializer} will be used.
    def self.serialize(event_body,
                       serializer: EventSourcery.config.event_body_serializer)
      serializer.serialize(event_body)
    end

    def initialize
      @serializers = Hash.new(IdentitySerializer)
    end

    # Register a serializer (instance or block) for the specified type
    #
    # @param type The type for which the provided serializer will be used for
    # @param serializer Optional. A serializer instance for the given type
    # @param block_serializer [Proc] Optional. A block that performs the serialization
    def add(type, serializer = nil, &block_serializer)
      @serializers[type] = serializer || block_serializer
      self
    end

    # Serialize the given event body
    #
    # @param event_body event body to be serialized
    def serialize(object)
      serializer = @serializers[object.class]
      serializer.call(object, &method(:serialize))
    end

    # Built in implementation for serializing Hash objects
    module HashSerializer
      def self.call(hash, &serialize)
        hash.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = serialize.call(value)
        end
      end
    end

    # Built in implementation for serializing Array objects
    module ArraySerializer
      def self.call(array, &serialize)
        array.map(&serialize)
      end
    end

    # Built in catch all implementation for serializing any object
    module IdentitySerializer
      def self.call(object)
        object
      end
    end
  end
end
