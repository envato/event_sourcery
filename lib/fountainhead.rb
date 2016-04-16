require 'virtus'
require 'rollbar'
require 'json'
require 'sequel'

Sequel.extension :pg_json
Sequel.default_timezone = :utc

require 'fountainhead/version'
require 'fountainhead/event'
require 'fountainhead/event_source_adapters/memory'
require 'fountainhead/event_source_adapters/postgres'
require 'fountainhead/event_source'
require 'fountainhead/event_sink_adapters/memory'
require 'fountainhead/event_sink_adapters/memory_with_stdout'
require 'fountainhead/event_sink_adapters/postgres'
require 'fountainhead/event_sink'
require 'fountainhead/event_subscriber_adapters/postgres'
require 'fountainhead/event_subscriber'
require 'fountainhead/processed_event_tracker_adapters/memory'
require 'fountainhead/processed_event_tracker_adapters/postgres'
require 'fountainhead/event_processor'
require 'fountainhead/table_owner'
require 'fountainhead/downstream_event_processor'
require 'fountainhead/processed_event_tracker'
require 'fountainhead/projector'
require 'fountainhead/command'
require 'fountainhead/postgres_schema'

module Fountainhead
end
