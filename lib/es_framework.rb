require 'virtus'
require 'rollbar'
require 'json'
require 'sequel'

Sequel.extension :pg_json
Sequel.default_timezone = :utc

require 'es_framework/version'
require 'es_framework/event'
require 'es_framework/event_source_adapters/memory'
require 'es_framework/event_source_adapters/postgres'
require 'es_framework/event_source'
require 'es_framework/event_sink_adapters/memory'
require 'es_framework/event_sink_adapters/memory_with_stdout'
require 'es_framework/event_sink_adapters/postgres'
require 'es_framework/event_sink'
require 'es_framework/event_subscriber_adapters/postgres'
require 'es_framework/event_subscriber'
require 'es_framework/processed_event_tracker_adapters/memory'
require 'es_framework/processed_event_tracker_adapters/postgres'
require 'es_framework/event_processor'
require 'es_framework/table_owner'
require 'es_framework/downstream_event_processor'
require 'es_framework/processed_event_tracker'
require 'es_framework/projector'
require 'es_framework/command'
require 'es_framework/postgres_schema'

module ESFramework
end
