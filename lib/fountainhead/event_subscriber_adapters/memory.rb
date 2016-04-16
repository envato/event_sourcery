module Fountainhead
  module EventSubscriberAdapters
    class Memory
      def initialize(event_sink)
        @event_sink = event_sink
      end

      def listen(&block)
        
      end

      def events(from:, to:, &block)
        @event_source.each_by_range(from, to, &block)
      end
    end
  end
end
