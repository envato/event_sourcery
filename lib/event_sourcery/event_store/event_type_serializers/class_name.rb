module EventSourcery
  module EventStore
    module EventTypeSerializers
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
