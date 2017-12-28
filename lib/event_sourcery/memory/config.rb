module EventSourcery
  module Memory
    class Config
      attr_accessor :event_tracker
      attr_writer :event_store, :event_source, :event_sink

      def initialize
        @event_tracker = Memory::Tracker.new
      end

      def event_store
        @event_store ||= EventStore.new
      end

      def event_source
        @event_source ||= ::EventSourcery::EventStore::EventSource.new(event_store)
      end

      def event_sink
        @event_sink ||= ::EventSourcery::EventStore::EventSink.new(event_store)
      end

    end

    def self.configure
      yield config
    end

    def self.config
      @config ||= Config.new
    end

  end
end
