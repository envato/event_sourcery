module EventSourcery
  class Event
    include Comparable

    def self.type
      unless self == Event
        EventSourcery.config.event_type_serializer.serialize(self)
      end
    end

    attr_reader :id, :uuid, :aggregate_id, :type, :body, :version, :created_at, :correlation_id, :causation_id

    def initialize(id: nil,
                   uuid: SecureRandom.uuid,
                   aggregate_id: nil,
                   type: nil,
                   body: nil,
                   version: nil,
                   created_at: nil,
                   correlation_id: nil,
                   causation_id: nil)
      @id = id
      @uuid = uuid && uuid.downcase
      @aggregate_id = aggregate_id.nil? ? nil : aggregate_id.to_str
      @type = self.class.type || type.to_s
      @body = body ? EventSourcery::EventBodySerializer.serialize(body) : {}
      @version = version ? Integer(version) : nil
      @created_at = created_at
      @correlation_id = correlation_id
      @causation_id = causation_id
    end

    def persisted?
      !id.nil?
    end

    def hash
      [self.class, uuid].hash
    end

    def eql?(other)
      instance_of?(other.class) && uuid.eql?(other.uuid)
    end

    def <=>(other)
      id <=> other.id if other.is_a? Event
    end

    def with(**attributes)
      self.class.new(**to_h.merge!(attributes))
    end

    def to_h
      {
        id:             id,
        uuid:           uuid,
        aggregate_id:   aggregate_id,
        type:           type,
        body:           body,
        version:        version,
        created_at:     created_at,
        correlation_id: correlation_id,
        causation_id:   causation_id,
      }
    end
  end
end
