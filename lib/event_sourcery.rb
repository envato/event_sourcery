require 'json'
require 'sequel'
require 'securerandom'

Sequel.extension :pg_json
Sequel.default_timezone = :utc

require 'event_sourcery/version'
require 'event_sourcery/event'
require 'event_sourcery/event_store/event_sink'
require 'event_sourcery/event_store/event_source'
require 'event_sourcery/errors'
require 'event_sourcery/event_store/each_by_range'
require 'event_sourcery/postgres/schema'
require 'event_sourcery/postgres/optimised_event_poll_waiter'
require 'event_sourcery/postgres/event_store'
require 'event_sourcery/postgres/event_store_with_optimistic_concurrency'
require 'event_sourcery/event_store/memory'
require 'event_sourcery/event_store/subscription'
require 'event_sourcery/event_store/poll_waiter'
require 'event_sourcery/event_store/event_builder'
require 'event_sourcery/event_store/event_type_serializers/class_name'
require 'event_sourcery/event_store/event_type_serializers/legacy'
require 'event_sourcery/event_store/event_type_serializers/underscored'
require 'event_sourcery/event_store/signal_handling_subscription_master'
require 'event_sourcery/event_processing/esp_process'
require 'event_sourcery/event_processing/esp_runner'
require 'event_sourcery/event_processing/event_trackers/memory'
require 'event_sourcery/event_processing/event_stream_processor'
require 'event_sourcery/event_processing/event_stream_processor_registry'
require 'event_sourcery/postgres/table_owner'
require 'event_sourcery/postgres/projector'
require 'event_sourcery/postgres/reactor'
require 'event_sourcery/postgres/tracker'
require 'event_sourcery/utils/queue_with_interval_callback'
require 'event_sourcery/config'
require 'event_sourcery/event_body_serializer'
require 'event_sourcery/aggregate_root'
require 'event_sourcery/repository'

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
