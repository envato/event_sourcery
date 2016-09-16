module EventSourcery
  class Config
    attr_accessor :event_sink,
                  :event_source,
                  :event_store,
                  :projections_database,
                  :event_store_database,
                  :event_tracker,
                  :on_unknown_event,
                  :use_optimistic_concurrency

    attr_writer :logger

    def initialize
      @on_unknown_event = proc { |event|
        raise Command::AggregateRoot::UnknownEventError.new("#{event.type} is unknown to #{self.class.name}")
      }
      @use_optimistic_concurrency = true
    end

    def event_store_database=(sequel_connection)
      @event_store_database = sequel_connection
      @event_store = EventStore::Postgres::Connection.new(sequel_connection)
      @event_sink = EventStore::EventSink.new(@event_store)
      @event_source = EventStore::EventSource.new(@event_store)
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
  end
end
