module EventSourcery
  class TypedEvent < Event
    def initialize(**hash)
      super(hash.reject { |k, v| k == :type })
    end

    def type
      self.class.name
    end
  end
end
