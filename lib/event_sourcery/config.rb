require 'logger'

module EventSourcery
  class Config
    attr_accessor :on_unknown_event,
                  :on_event_processor_error,
                  :event_type_serializer,
                  :error_handler_class

    attr_writer :logger,
                :event_body_serializer,
                :event_builder

    def initialize
      @on_unknown_event = proc { |event, aggregate|
        raise AggregateRoot::UnknownEventError, "#{event.type} is unknown to #{aggregate.class.name}"
      }
      @on_event_processor_error = proc { |exception, processor_name|
        # app specific custom logic ie. report to rollbar
      }
      @event_store = nil
      @event_type_serializer = EventStore::EventTypeSerializers::Underscored.new
      @error_handler_class = EventProcessing::ErrorHandlers::ConstantRetry
    end

    def logger
      @logger ||= ::Logger.new(STDOUT).tap do |logger|
        logger.level = Logger::DEBUG
      end
    end

    def event_builder
      @event_builder || EventStore::EventBuilder.new(event_type_serializer: @event_type_serializer)
    end

    def event_body_serializer
      @event_body_serializer ||= EventBodySerializer.new
        .add(Hash, EventBodySerializer::HashSerializer)
        .add(Array, EventBodySerializer::ArraySerializer)
        .add(Time, &:iso8601)
    end
  end
end
