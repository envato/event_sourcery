module EventSourcery
  class EventBodySerializer
    def self.serialize(event_body)
      new(event_body).serialize
    end

    def initialize(event_body)
      @event_body = event_body
    end

    def serialize
      case event_body
      when Hash
        serialize_hash(event_body)
      when Array
        serialize_array(event_body)
      else
        serialize_object(event_body)
      end
    end

    private

    attr_reader :event_body

    def serialize_object(object)
      case object
      when Hash, Array
        self.class.serialize(object)
      when Time
        object.iso8601
      else
        object
      end
    end

    def serialize_hash(hash)
      hash.each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = serialize_object(value)
      end
    end

    def serialize_array(array)
      array.map do |object|
        serialize_object(object)
      end
    end
  end
end
