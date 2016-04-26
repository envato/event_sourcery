require 'virtus'
require 'rollbar'
require 'json'
require 'sequel'

Sequel.extension :pg_json
Sequel.default_timezone = :utc

require 'event_sourcery/version'
require 'event_sourcery/event'
require 'event_sourcery/event_source_adapters/memory'
require 'event_sourcery/event_source_adapters/postgres'
require 'event_sourcery/event_source'
require 'event_sourcery/event_sink_adapters/memory'
require 'event_sourcery/event_sink_adapters/memory_with_stdout'
require 'event_sourcery/event_sink_adapters/postgres'
require 'event_sourcery/event_sink'
require 'event_sourcery/event_feeder'
require 'event_sourcery/event_feeder_adapters/postgres_push'
require 'event_sourcery/event_feeder_adapters/postgres_push/new_event_subscriber'
require 'event_sourcery/processed_event_tracker_adapters/memory'
require 'event_sourcery/processed_event_tracker_adapters/postgres'
require 'event_sourcery/event_processor'
require 'event_sourcery/table_owner'
require 'event_sourcery/downstream_event_processor'
require 'event_sourcery/processed_event_tracker'
require 'event_sourcery/projector'
require 'event_sourcery/command'
require 'event_sourcery/postgres_schema'
require 'event_sourcery/errors'

module EventSourcery
end
