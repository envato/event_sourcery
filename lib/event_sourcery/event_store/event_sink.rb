# frozen_string_literal: true

require 'forwardable'

module EventSourcery
  module EventStore
    # Delegates event storage operations to the underlying event store.
    class EventSink
      def initialize(event_store)
        @event_store = event_store
      end

      extend Forwardable
      def_delegators :event_store, :sink

      private

      attr_reader :event_store
    end
  end
end
