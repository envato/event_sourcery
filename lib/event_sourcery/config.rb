require 'logger'

module EventSourcery
  class Config
    # The default Proc to be run when an aggregate loads an event type that
    # it doesn't know how to handle.
    # What's specified here can be overridden when instantiating an aggregate
    # instance. {AggregateRoot#initialize}
    #
    # If no custom Proc is set, by default behaviour is to raise {AggregateRoot::UnknownEventError}
    #
    # @return Proc
    attr_accessor :on_unknown_event

    # A Proc to be executed on an event processor error.
    # App specific custom logic can be provided.
    # i.e. report to an error reporting service like Rollbar.
    #
    # @return Proc
    attr_accessor :on_event_processor_error

    # @return EventStore::EventTypeSerializers::Underscored
    attr_accessor :event_type_serializer

    # @return EventProcessing::ErrorHandlers::ConstantRetry
    attr_accessor :error_handler_class

    attr_writer :logger,
                :event_body_serializer,
                :event_builder

    # @return Integer
    attr_accessor :subscription_batch_size

    # @api private
    def initialize
      @on_unknown_event = proc { |event, aggregate|
        raise AggregateRoot::UnknownEventError, "#{event.type} is unknown to #{aggregate.class.name}"
      }
      @on_event_processor_error = proc { |exception, processor_name|
        # app specific custom logic ie. report to an error reporting service like Rollbar.
      }
      @event_builder = nil
      @event_type_serializer = EventStore::EventTypeSerializers::Underscored.new
      @error_handler_class = EventProcessing::ErrorHandlers::ConstantRetry
      @subscription_batch_size = 1000
    end

    # Logger instance used by EventSourcery.
    # By default EventSourcery will log to STDOUT with a log level of Logger::DEBUG
    def logger
      @logger ||= ::Logger.new(STDOUT).tap do |logger|
        logger.level = Logger::DEBUG
      end
    end

    # The event builder used by an event store to build event instances.
    # By default {EventStore::EventBuilder} will be used.
    # Provide a custom builder here to change how an event is built.
    def event_builder
      @event_builder || EventStore::EventBuilder.new(event_type_serializer: @event_type_serializer)
    end

    # The event body serializer used by the default event builder
    # ({EventStore::EventBuilder}). By default {EventBodySerializer} will be used.
    # Provide a custom serializer here to change how the event body is serialized.
    def event_body_serializer
      @event_body_serializer ||= EventBodySerializer.new
        .add(Hash, EventBodySerializer::HashSerializer)
        .add(Array, EventBodySerializer::ArraySerializer)
        .add(Time, &:iso8601)
    end
  end
end
