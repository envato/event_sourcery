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
    end

    attr_reader :aggregate_id, :payload

    def initialize(aggregate_id:, payload:)
      @aggregate_id = aggregate_id
      @payload = payload
    end

    def validate!
      raise NotImplementedError
    end
  end
end
