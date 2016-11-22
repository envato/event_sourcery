module EventSourcery
  class Event
    EVENT_SOURCERY_CLASS_NAME = 'EventSourcery::Event'.freeze
    include Virtus.value_object

    def initialize(**hash)
      hash[:body] = EventSourcery::EventBodySerializer.serialize(hash[:body]) if hash[:body]
      hash[:uuid] ||= SecureRandom.uuid
      hash[:type] ||= underscored_class_name
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

    def self.attribute(name, default: nil)
      define_method(name) do
        body.fetch(name.to_s, default)
      end
    end

    private

    def underscored_class_name
      unless self.class.name == EVENT_SOURCERY_CLASS_NAME
        EventSourcery.config.inflector.underscore(self.class.name)
      end
    end
  end
end
