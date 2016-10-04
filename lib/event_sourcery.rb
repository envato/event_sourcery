require 'virtus'
require 'json'
require 'sequel'

Sequel.extension :pg_json
Sequel.default_timezone = :utc

require 'event_sourcery/version'
require 'event_sourcery/event'
require 'event_sourcery/event_store/event_sink'
require 'event_sourcery/event_store/event_source'
require 'event_sourcery/command'
require 'event_sourcery/errors'
require 'event_sourcery/event_store/each_by_range'
require 'event_sourcery/event_store/postgres/connection'
require 'event_sourcery/event_store/postgres/connection_with_optimistic_concurrency'
require 'event_sourcery/event_store/memory'
require 'event_sourcery/event_store/postgres/schema'
require 'event_sourcery/event_store/subscription'
require 'event_sourcery/event_store/poll_waiter'
require 'event_sourcery/event_store/postgres/optimised_event_poll_waiter'
require 'event_sourcery/event_processing/event_dispatcher'
require 'event_sourcery/event_processing/event_trackers/memory'
require 'event_sourcery/event_processing/event_trackers/postgres'
require 'event_sourcery/event_processing/event_stream_processor'
require 'event_sourcery/event_processing/table_owner'
require 'event_sourcery/event_processing/event_reactor'
require 'event_sourcery/event_processing/event_stream_processor_registry'
require 'event_sourcery/event_processing/projector'
require 'event_sourcery/utils/queue_with_interval_callback'
require 'event_sourcery/config'
require 'event_sourcery/event_body_serializer'
require 'event_sourcery/command/aggregate_root'
require 'event_sourcery/command/repository'

module EventSourcery
  def self.configure
    yield config
  end

  def self.config
    @config ||= Config.new
  end

  def self.logger
    config.logger
  end

  def self.event_stream_processor_registry
    @event_stream_processor_registry ||= EventProcessing::EventStreamProcessorRegistry.new
  end
end
