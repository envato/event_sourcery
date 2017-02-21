module EventSourcery
  module EventStore
    module EventTypeSerializers
      # Stores event types by the underscored version of the class name and
      # falls back to the generic Event class if the constant is not found
      class Underscored
        def initialize
          @cache = {}
        end

        def serialize(event_class)
          unless event_class == Event
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

        private

        def lookup_type(event_type)
          Object.const_get(camelize(event_type))
        rescue NameError
          Event
        end

        def underscore_class_name(class_name)
          underscore(class_name)
        end

        # Inflection methods are taken from active support 3.2
        # https://github.com/rails/rails/blob/3-2-stable/activesupport/lib/active_support/inflector/methods.rb
        def underscore(camel_cased_word)
          word = camel_cased_word.to_s.dup
          word.gsub!(/::/, '/')
          word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
          word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
          word.tr!("-", "_")
          word.downcase!
          word
        end

        def camelize(term, uppercase_first_letter = true)
          string = term.to_s
          if uppercase_first_letter
            string = string.sub(/^[a-z\d]*/) { capitalize($&) }
          else
            string = string.sub(/^(?:(?=\b|[A-Z_])|\w)/) { $&.downcase }
          end
          string.gsub(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{capitalize($2)}" }.gsub('/', '::')
        end

        def capitalize(lower_case_and_underscored_word)
          result = lower_case_and_underscored_word.to_s.dup
          result.gsub!(/_id$/, "")
          result.gsub!(/_/, ' ')
          result.gsub(/([a-z\d]*)/i) { |match|
            "#{match.downcase}"
          }.gsub(/^\w/) { $&.upcase }
        end
      end
    end
  end
end
