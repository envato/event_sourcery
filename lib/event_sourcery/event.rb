module EventSourcery
  class Event
    include Virtus.value_object

    def self.type
      unless self == Event
        EventSourcery.config.event_type_serializer.serialize(self)
      end
    end

    def initialize(**hash)
      hash[:body] = EventSourcery::EventBodySerializer.serialize(hash[:body]) if hash[:body]
      hash[:uuid] ||= SecureRandom.uuid
      hash[:type] = self.class.type || hash[:type]
      super
    end

    values do
      attribute :id, Integer
      attribute :uuid, String
      attribute :aggregate_id, String
      attribute :type, String
      attribute :body, Hash
      attribute :version, Integer
      attribute :created_at, Time
    end

    def persisted?
      !id.nil?
    end
  end
end
