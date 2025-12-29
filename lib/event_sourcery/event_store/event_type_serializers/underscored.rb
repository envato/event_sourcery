# frozen_string_literal: true

module EventSourcery
  module EventStore
    module EventTypeSerializers
      # Stores event types by the underscored version of the class name and
      # falls back to the generic Event class if the constant is not found
      #
      # Replace inflector with ActiveSupport like this:
      # EventSourcery::EventStore::EventTypeSerializers::Underscored.inflector = ActiveSupport::Inflector
      class Underscored
        class Inflector
          # Inflection methods are taken from active support 3.2
          # https://github.com/rails/rails/blob/3-2-stable/activesupport/lib/active_support/inflector/methods.rb
          def underscore(camel_cased_word)
            word = camel_cased_word.to_s.dup
            word.gsub!(/::/, '/')
            word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
            word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
            word.tr!('-', '_')
            word.downcase!
            word
          end

          def camelize(term, uppercase_first_letter = true)
            string = term.to_s
            string =
              if uppercase_first_letter
                string.sub(/^[a-z\d]*/) { capitalize(::Regexp.last_match(0)) }
              else
                string.sub(/^(?:(?=\b|[A-Z_])|\w)/) { ::Regexp.last_match(0).downcase }
              end
            string.gsub(%r{(?:_|(/))([a-z\d]*)}i) do
              "#{::Regexp.last_match(1)}#{capitalize(::Regexp.last_match(2))}"
            end.gsub('/', '::')
          end

          private

          def capitalize(lower_case_and_underscored_word)
            result = lower_case_and_underscored_word.to_s.dup
            result.gsub!(/_id$/, '')
            result.gsub!(/_/, ' ')
            result.gsub!(/([a-z\d]*)/i, &:downcase)
            result.gsub(/^\w/) { ::Regexp.last_match(0).upcase }
          end
        end

        class << self
          attr_accessor :inflector
        end
        @inflector = Inflector.new

        def serialize(event_class)
          underscore_class_name(event_class.name)
        end

        def deserialize(event_type)
          Object.const_get(self.class.inflector.camelize(event_type))
        rescue NameError
          Event
        end

        private

        def underscore_class_name(class_name)
          self.class.inflector.underscore(class_name)
        end
      end
    end
  end
end
