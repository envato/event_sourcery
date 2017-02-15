module EventSourcery
  module EventStore
    module EventTypeSerializers
      # To support legacy implementations.
      # Type is stored as a property of the event
      class Legacy
        def serialize(event)
          nil
        end

        def deserialize(event_type)
          Event
        end
      end
    end
  end
end
