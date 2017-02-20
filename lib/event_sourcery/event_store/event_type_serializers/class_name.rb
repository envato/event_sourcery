module EventSourcery
  module EventStore
    module EventTypeSerializers
      # Stores event types by their class name and falls back to the generic
      # Event class if the constant is not found
      class ClassName
        def serialize(event_class)
          unless event_class == Event
            event_class.name
          end
        end

        def deserialize(event_type)
          Object.const_get(event_type)
        rescue NameError
          Event
        end
      end
    end
  end
end
