module EventSourcery
  class Event < GenericEvent
    def self.resolve_type(type)
      Object.const_get(event_type)
    rescue NameError
      GenericEvent
    end

    def initialize(**hash)
      super(hash.reject { |k, v| k == :type })
    end

    def type
      self.class.name
    end
  end
end
