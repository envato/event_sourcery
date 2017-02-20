module EventSourcery
  module Command
    module AggregateRoot
      UnknownEventError = Class.new(RuntimeError)
      RejectedCommandError = Class.new(RuntimeError)

      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          @event_handlers = Hash.new { |hash, key| hash[key] = [] }
        end
      end

      module ClassMethods
        attr_reader :event_handlers

        def apply(*event_classes, &block)
          event_classes.each do |event_class|
            @event_handlers[event_class.type] << block
          end
        end
      end

      def initialize(id, event_sink, on_unknown_event: EventSourcery.config.on_unknown_event, use_optimistic_concurrency: EventSourcery.config.use_optimistic_concurrency)
        @id = id
        @event_sink = event_sink
        @current_version = 0
        @on_unknown_event = on_unknown_event
        @use_optimistic_concurrency = use_optimistic_concurrency
      end

      def load_history(events)
        events.each do |event|
          apply_event(event)
          @current_version = event.version if @use_optimistic_concurrency
        end
      end

      private

      attr_reader :id, :event_sink

      def apply_event(event_or_hash)
        event = to_event(event_or_hash)
        mutate_state_from(event)
        unless event.persisted?
          event_with_aggregate_id = Event.new(aggregate_id: @id,
                                              type: event.type,
                                              body: event.body)
          if @use_optimistic_concurrency
            event_sink.sink(event_with_aggregate_id, expected_version: @current_version)
            @current_version += 1
          else
            event_sink.sink(event_with_aggregate_id)
          end
        end
      end

      def to_event(event_or_hash)
        if event_or_hash.is_a?(Event)
          event_or_hash
        else
          Event.new(event_or_hash)
        end
      end

      def mutate_state_from(event)
        handlers = self.class.event_handlers[event.type]
        if handlers.any?
          handlers.each do |handler|
            instance_exec(event, &handler)
          end
        else
          # TODO: remove support for this approach in a future release
          method_name = "apply_#{event.type}"

          if respond_to?(method_name, true)
            send(method_name, event)
          else
            @on_unknown_event.call(event, self)
          end
        end
      end
    end
  end
end
