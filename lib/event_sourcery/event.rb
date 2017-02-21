module EventSourcery
  class Event
    include Virtus.value_object

    def initialize(**hash)
      hash[:body] = EventSourcery::EventBodySerializer.serialize(hash[:body]) if hash[:body]
      hash[:uuid] ||= SecureRandom.uuid
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

    def ==(other)
      type.to_sym == other.type.to_sym && body == other.body
    end
  end
end
