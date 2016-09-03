module EventSourcery
  module CommandHandler
    def self.included(base)
      base.prepend(HandleWrapper)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def handle(command, event_source = EventSource, event_sink = EventSink)
        new(event_source, event_sink).tap { |handler| handler.handle(command) }
      end
    end

    def initialize(event_source, event_sink)
      @event_source = event_source
      @event_sink = event_sink
    end

    def handle(command)
      raise NotImplementedError
    end

    private

    attr_reader :event_source, :event_sink
  end
end
