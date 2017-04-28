require 'virtus'

module EventSourcery
  module Command
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def build!(**args)
        new(**args).tap do |command|
          command.validate!
        end
      end

      def attributes
        @@attributes ||= {}
      end

      def attribute(name, type, options={})
        if [ :aggregate_id, :payload ].include?(name.to_sym)
          raise ReservedAttributeName, "'#{name}' is a reserved attribute name"
        end

        attr_reader name

        virtus_options = { strict: true }
        virtus_options[:required] = false if options[:optional]

        self.attributes[name] = ::Virtus::Attribute.build(type, virtus_options)
      end
    end

    def initialize(aggregate_id:, payload:)
      @aggregate_id = aggregate_id
      @payload = payload
    end

    def validate!
      self.class.attributes.each do |attribute_name, coercer|
        instance_variable_set("@#{attribute_name}", coercer.coerce(@payload[attribute_name]))
      end
    end
  end
end
