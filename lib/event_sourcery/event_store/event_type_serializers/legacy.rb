module EventSourcery
  module EventStore
    module EventTypeSerializers
      # To support legacy implementations.  Type is provided when initializing
      # the event, not derived from the class constant
      class Legacy
        def serialize(event_class)
          nil
        end

        def deserialize(event_type)
          Event
        end
      end
    end
  end
end
