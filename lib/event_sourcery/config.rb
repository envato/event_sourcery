require 'logger'

module EventSourcery
  class Config
    attr_accessor :event_store_database,
                  :event_tracker,
                  :on_unknown_event,
                  :on_event_processor_error,
                  :use_optimistic_concurrency,
                  :lock_table_to_guarantee_linear_sequence_id_growth,
                  :write_events_function_name,
                  :events_table_name,
                  :aggregates_table_name,
                  :callback_interval_if_no_new_events,
                  :event_type_serializer,
                  :auto_create_projector_tracker

    attr_writer :event_store,
                :event_source,
                :event_sink,
                :logger,
                :event_builder

    attr_reader :projections_database,
                :upcaster_chain

    def initialize
      @on_unknown_event = proc { |event, aggregate|
        raise Command::AggregateRoot::UnknownEventError, "#{event.type} is unknown to #{aggregate.class.name}"
      }
      @on_event_processor_error = proc { |exception, processor_name|
        # app specific custom logic ie. report to rollbar
      }
      @use_optimistic_concurrency = true
      @lock_table_to_guarantee_linear_sequence_id_growth = true
      @write_events_function_name = 'writeEvents'
      @events_table_name = :events
      @aggregates_table_name = :aggregates
      @callback_interval_if_no_new_events = 10
      @event_store_database = nil
      @event_store = nil
      @upcaster_chain = EventStore::UpcasterChain.new
      @event_type_serializer = EventStore::EventTypeSerializers::Underscored.new
      @auto_create_projector_tracker = true
    end

    def event_store
      if @event_store_database
        if use_optimistic_concurrency
          EventStore::Postgres::ConnectionWithOptimisticConcurrency.new(@event_store_database)
        else
          EventStore::Postgres::Connection.new(@event_store_database)
        end
      else
        @event_store
      end
    end

    def event_source
      @event_source ||= EventStore::EventSource.new(event_store)
    end

    def event_sink
      @event_sink ||= EventStore::EventSink.new(event_store)
    end

    def projections_database=(sequel_connection)
      @projections_database = sequel_connection
      @event_tracker = EventProcessing::EventTrackers::Postgres.new(sequel_connection)
    end

    def logger
      @logger ||= ::Logger.new(STDOUT).tap do |logger|
        logger.level = Logger::DEBUG
      end
    end

    def event_builder
      @event_builder || EventStore::EventBuilder.new(event_type_serializer: event_type_serializer, upcaster_chain: upcaster_chain)
    end
  end
end
