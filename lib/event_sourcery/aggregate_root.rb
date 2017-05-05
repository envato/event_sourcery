module EventSourcery
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

    def initialize(id, events, on_unknown_event: EventSourcery.config.on_unknown_event)
      @id = id
      @version = 0
      @on_unknown_event = on_unknown_event
      @changes = []
      load_history(events)
    end

    attr_reader :changes, :version

    def clear_changes!
      @changes.clear
    end

    private

    def load_history(events)
      events.each do |event|
        mutate_state_from(event)
      end
    end

    attr_reader :id

    def apply_event(event_class, options = {})
      event = event_class.new(**options.merge(aggregate_id: id))
      mutate_state_from(event)
      @changes << event
    end

    def mutate_state_from(event)
      handlers = self.class.event_handlers[event.type]
      if handlers.any?
        handlers.each do |handler|
          instance_exec(event, &handler)
        end
      else
        @on_unknown_event.call(event, self)
      end
      increment_version
    end

    def increment_version
      @version += 1
    end
  end
end
