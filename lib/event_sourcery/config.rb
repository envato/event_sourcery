require 'logger'

module EventSourcery
  class Config
    attr_accessor :event_sink,
                  :event_source,
                  :event_store,
                  :projections_database,
                  :event_store_database,
                  :event_tracker,
                  :on_unknown_event,
                  :use_optimistic_concurrency,
                  :lock_table_to_guarantee_linear_sequence_id_growth,
                  :write_events_function_name,
                  :events_table_name,
                  :callback_interval_if_no_new_events

    attr_writer :logger

    def initialize
      @on_unknown_event = proc { |event|
        raise Command::AggregateRoot::UnknownEventError.new("#{event.type} is unknown to #{self.class.name}")
      }
      @use_optimistic_concurrency = true
      @lock_table_to_guarantee_linear_sequence_id_growth = true
      @write_events_function_name = 'writeEvents'
      @events_table_name = :events
      @callback_interval_if_no_new_events = 10
    end

    def use_optimistic_concurrency=(value)
      @use_optimistic_concurrency = value
      set_database_event_store(@event_store_database) if @event_store_database
    end

    def event_store_database=(sequel_connection)
      @event_store_database = sequel_connection
      set_database_event_store(sequel_connection)
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

    private

    def set_database_event_store(sequel_connection)
      @event_store = if use_optimistic_concurrency
        EventStore::Postgres::ConnectionWithOptimisticConcurrency.new(sequel_connection)
      else
        EventStore::Postgres::Connection.new(sequel_connection)
      end
    end
  end
end
