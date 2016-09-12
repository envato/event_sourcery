module EventSourcery
  class Event
    include Virtus.value_object

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
  end
end
