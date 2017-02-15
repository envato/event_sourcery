module EventSourcery
  module EventStore
    module EventTypeSerializers
      class ClassName
        def serialize(event)
          unless event.class == Event
            event.class.name
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
