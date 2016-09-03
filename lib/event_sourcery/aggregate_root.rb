module EventSourcery
  module AggregateRoot
    UnknownEventError = Class.new(RuntimeError)

    def initialize(id, event_sink)
      @id = id
      @event_sink = event_sink
    end

    def load_history(events)
      events.each do |event|
        apply_event(event)
      end
    end

    private

    attr_reader :id, :event_sink

    def apply_event(event)
      mutate_state_from(event)
      event_sink.sink(id, event) if event.id.nil?
    end

    def mutate_state_from(event)
      method_name = "apply_#{event.type}"

      if respond_to?(method_name, true)
        send(method_name, event)
      else
        raise UnknownEventError.new("#{event.type} is unknown to #{self.class.name}")
      end
    end
  end
end
