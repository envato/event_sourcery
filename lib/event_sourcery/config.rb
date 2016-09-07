module EventSourcery
  class Config
    attr_accessor :event_sink,
                  :event_source,
                  :event_store,
                  :projections_database,
                  :event_store_database,
                  :event_tracker

    def event_store_database=(sequel_connection)
      @event_store_database = sequel_connection
      @event_store = EventStore::Postgres::Connection.new(sequel_connection)
      @event_sink = EventStore::EventSink.new(@event_store_connection)
      @event_source = EventStore::EventSource.new(@event_store_connection)
    end

    def projections_database=(sequel_connection)
      @projections_database = sequel_connection
      @event_tracker = EventProcessing::EventTrackers::Postgres.new(sequel_connection)
    end
  end
end
