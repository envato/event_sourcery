module EventSourcery
  class GenericEvent
    include Virtus.value_object

    def self.resolve_type(type)
      self
    end

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
      attribute :version, Bignum
      attribute :created_at, Time
    end

    def persisted?
      !id.nil?
    end
  end
end
