module EventSourcery
  module EventStore
    module EventClassResolvers
      class ClassName
        def resolve(event_type)
          Object.const_get(event_type)
        end
      end
    end
  end
end
