module ESFramework
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
    end

    def validate!
      raise NotImplementedError
    end
  end
end
