module EventSourcery
  module EventHandler
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def handles_event_types
        @handles_event_types ||= []
      end

      def handles_events(*event_types)
        @handles_event_types = event_types.map(&:to_s)
      end

      def handles_all_events
        define_singleton_method :handles? do |_|
          true
        end
      end

      def handles?(event_type)
        handles_event_types.include?(event_type.to_s)
      end

      def handler_name=(name)
        @handler_name = name
      end

      def handler_name
        @handler_name || self.name
      end

      attr_reader :event_types
    end

    private

    attr_reader :tracker
  end
end
