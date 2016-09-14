module EventSourcery
  class Event
    include Virtus.value_object

    def initialize(**hash)
      hash[:body] = stringify_keys(hash[:body]) if hash[:body].is_a? Hash
      super
    end

    values do
      attribute :id, Integer
      attribute :aggregate_id, String
      attribute :type, String
      attribute :body, Hash
      attribute :created_at, Time
    end

    def persisted?
      !id.nil?
    end

    private

    def stringify_keys(hash)
      hash.inject({}) do |memo, (key, value)|
        memo[key.to_s] = value
        memo
      end
    end
  end
end
