module EventSourcery
  # This class provides a set of methods to help load and save aggregate instances.
  #
  # Refer to {https://github.com/envato/event_sourcery_todo_app/blob/31e200f4a2a65be5d847a66a20e23a334d43086b/app/commands/todo/amend.rb#L26 EventSourceryTodoApp}
  # for a more complete example.
  #@example
  #  repository = EventSourcery::Repository.new(
  #    event_source: EventSourceryTodoApp.event_source,
  #    event_sink: EventSourceryTodoApp.event_sink,
  #  )
  #
  #  aggregate = repository.load(Aggregates::Todo, command.aggregate_id)
  #  aggregate.amend(command.payload)
  #  repository.save(aggregate)
  class Repository
    # Create a new instance of the repository and load an aggregate instance
    #@param aggregate_class Aggregate type
    #@param aggregate_id [Integer] ID of the aggregate instance to be loaded
    #@param event_source event source to be used for loading the events for the aggregate
    #@param event_sink event sink to be used for saving any new events for the aggregate
    def self.load(aggregate_class, aggregate_id, event_source:, event_sink:)
      new(event_source: event_source, event_sink: event_sink).load(aggregate_class, aggregate_id)
    end

    #@param event_source event source to be used for loading the events for the aggregate
    #@param event_sink event sink to be used for saving any new events for the aggregate
    def initialize(event_source:, event_sink:)
      @event_source = event_source
      @event_sink = event_sink
    end

    # Load an aggregate instance
    #@param aggregate_class Aggregate type
    #@param aggregate_id [Integer] ID of the aggregate instance to be loaded
    def load(aggregate_class, aggregate_id)
      events = event_source.get_events_for_aggregate_id(aggregate_id)
      aggregate_class.new(aggregate_id, events)
    end

    # Save any new events/changes in the provided aggregate to the event sink
    #@param aggregate An aggregate instance to be saved
    def save(aggregate)
      new_events = aggregate.changes
      if new_events.any?
        event_sink.sink(new_events, expected_version: aggregate.version - new_events.count)
      end
      aggregate.clear_changes
    end

    private

    attr_reader :event_source, :event_sink
  end
end
