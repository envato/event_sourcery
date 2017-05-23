module EventSourcery
  class EventBodySerializer
    def self.serialize(event_body,
                       serializer: EventSourcery.config.event_body_serializer)
      serializer.serialize(event_body)
    end

    def initialize
      @serializers = Hash.new(IdentitySerializer)
    end

    def add(type, serializer)
      @serializers[type] = serializer
      self
    end

    def serialize(object)
      serializer = @serializers[object.class]
      serializer.serialize(object, &method(:serialize))
    end

    module HashSerializer
      def self.serialize(hash, &serialize)
        hash.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = serialize.call(value)
        end
      end
    end

    module ArraySerializer
      def self.serialize(array, &serialize)
        array.map(&serialize)
      end
    end

    module TimeSerializer
      def self.serialize(time)
        time.iso8601
      end
    end

    module IdentitySerializer
      def self.serialize(object)
        object
      end
    end
  end
end
