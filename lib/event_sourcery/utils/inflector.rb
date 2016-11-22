module EventSourcery
  module Utils
    # Basic implementation from ActiveSupport to avoid requiring a dependency on ActiveSupport
    module Inflector
      extend self

      def underscore(camel_cased_word)
        return camel_cased_word unless !!/[A-Z-]|::/.match(camel_cased_word)
        word = camel_cased_word.to_s.gsub("::".freeze, "/".freeze)
        word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2'.freeze)
        word.gsub!(/([a-z\d])([A-Z])/, '\1_\2'.freeze)
        word.tr!("-".freeze, "_".freeze)
        word.downcase!
        word
      end
    end
  end
end
