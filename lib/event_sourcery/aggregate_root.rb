module EventSourcery
  #
  # EventSourcery::AggregateRoot provides a foundation for writing your own aggregate root classes.
  # You can use it by including it in your classes, as show in the example code.
  #
  # Excerpt from {https://github.com/envato/event_sourcery/blob/HEAD/docs/core-concepts.md EventSourcery Core Concepts} on Aggregates follows:
  # === Aggregates and Command Handling
  #
  #   An aggregate is a cluster of domain objects that can be treated as a single unit.
  #   Every transaction is scoped to a single aggregate. An aggregate will have one of its component objects be
  #   the aggregate root. Any references from outside the aggregate should only go to the aggregate root.
  #   The root can thus ensure the integrity of the aggregate as a whole.
  #
  #   — DDD Aggregate
  #
  # Clients execute domain transactions against the system by issuing commands against aggregate roots.
  # The result of these commands is new events being saved to the event store.
  # A typical EventSourcery application will have one or more aggregate roots with multiple commands.
  #
  # The following partial example is taken from the EventSourceryTodoApp.
  # Refer a more complete example {https://github.com/envato/event_sourcery_todo_app/blob/HEAD/app/aggregates/todo.rb here}.
  #
  # @example
  #   module EventSourceryTodoApp
  #     module Aggregates
  #       class Todo
  #         include EventSourcery::AggregateRoot
  #
  #         # An event handler that updates the aggregate's state from a event
  #         apply TodoAdded do |event|
  #           @added = true
  #         end
  #
  #         # Method on the aggregate that processes a command and emits an event as a result
  #         def add(payload)
  #           raise UnprocessableEntity, "Todo #{id.inspect} already exists" if added
  #
  #           apply_event(TodoAdded,
  #                       aggregate_id: id,
  #                       body: payload,
  #           )
  #        end
  #
  #         private
  #
  #         attr_reader :added
  #       end
  #     end
  #   end
  module AggregateRoot
    # Raised when the aggregate doesn't have a method to handle a given event.
    # Consider implementing one if you get this error.
    UnknownEventError = Class.new(RuntimeError)

    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        @event_handlers = Hash.new { |hash, key| hash[key] = [] }
      end
    end

    module ClassMethods
      # Collection of event handlers for the events that this aggregate cares about
      #
      # @return Hash
      attr_reader :event_handlers

      # Register an event handler for the specified event(s)
      #
      # @param event_classes one or more event types for which the handler is for
      # @param block the event handler
      #
      # @example
      #   apply TodoAdded do |event|
      #     @added = true
      #   end
      def apply(*event_classes, &block)
        event_classes.each do |event_class|
          @event_handlers[event_class.type] << block
        end
      end
    end

    # Load an aggregate instance based on the given ID and events
    #
    # @param id [String] ID (a UUID represented as a string) of the aggregate instance to be loaded
    # @param events [Array] Events from which the aggregate's current state will be formed
    # @param on_unknown_event [Proc] Optional. The proc to be run if an unknown event type (for which no event handler is registered using {ClassMethods#apply}) is to be loaded.
    def initialize(id, events, on_unknown_event: EventSourcery.config.on_unknown_event)
      @id = id.to_str
      @version = 0
      @on_unknown_event = on_unknown_event
      @changes = []
      load_history(events)
    end

    # Collection of new events that are yet to be persisted
    #
    # @return Array
    attr_reader :changes

    # Current version of the aggregate. This is the same as the number of events
    # currently loaded by the aggregate.
    #
    # @return Integer
    attr_reader :version

    # Clears any changes present in {changes}
    #
    # @api private
    def clear_changes
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
