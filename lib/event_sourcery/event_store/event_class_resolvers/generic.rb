module EventSourcery
  module EventStore
    module EventClassResolvers
      class Generic
        def resolve(event_type)
          Event
        end
      end
    end
  end
end
