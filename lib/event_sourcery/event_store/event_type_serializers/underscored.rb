require 'active_support/all' # TODO: only load string exts and consider alternatives to this dependency

module EventSourcery
  module EventStore
    module EventTypeSerializers
      # Stores event types by the underscored version of the class name and
      # falls back to the generic Event class
      class Underscored
        def initialize
          @cache = {}
        end

        def serialize(event_class)
          if event_class == Event
            nil
          else
            underscore_class_name(event_class.name)
          end
        end

        def deserialize(event_type)
          if @cache.key?(event_type)
            @cache.fetch(event_type)
          else
            @cache[event_type] = lookup_type(event_type)
          end
        end

        def lookup_type(event_type)
          Object.const_get(event_type.camelize)
        rescue NameError
          Event
        end

        def underscore_class_name(class_name)
          class_name.underscore
        end
      end
    end
  end
end
