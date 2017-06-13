require 'json'
require 'securerandom'

require 'event_sourcery/version'
require 'event_sourcery/event'
require 'event_sourcery/event_store/event_sink'
require 'event_sourcery/event_store/event_source'
require 'event_sourcery/errors'
require 'event_sourcery/event_store/each_by_range'
require 'event_sourcery/event_store/memory'
require 'event_sourcery/event_store/subscription'
require 'event_sourcery/event_store/poll_waiter'
require 'event_sourcery/event_store/event_builder'
require 'event_sourcery/event_store/event_type_serializers/class_name'
require 'event_sourcery/event_store/event_type_serializers/legacy'
require 'event_sourcery/event_store/event_type_serializers/underscored'
require 'event_sourcery/event_store/signal_handling_subscription_master'
require 'event_sourcery/event_processing/error_handlers/error_handler'
require 'event_sourcery/event_processing/error_handlers/no_retry'
require 'event_sourcery/event_processing/error_handlers/constant_retry'
require 'event_sourcery/event_processing/error_handlers/exponential_backoff_retry'
require 'event_sourcery/event_processing/esp_process'
require 'event_sourcery/event_processing/esp_runner'
require 'event_sourcery/event_processing/event_trackers/memory'
require 'event_sourcery/event_processing/event_stream_processor'
require 'event_sourcery/event_processing/event_stream_processor_registry'
require 'event_sourcery/config'
require 'event_sourcery/event_body_serializer'
require 'event_sourcery/aggregate_root'
require 'event_sourcery/repository'

module EventSourcery
  # Method for configuring EventSourcery
  #
  # Example Usage:
  #
  #   EventSourcery.configure do |config|
  #     # Add custom reporting of errors occurring during event processing.
  #     # One might set up an error reporting service like Rollbar here.
  #     config.on_event_processor_error = proc { |exception, processor_name| … }
  #
  #     # Enable Event Sourcery logging.
  #     config.logger = Logger.new('logs/my_event_sourcery_app.log')
  #
  #     # Customize how event body attributes are serialized
  #     config.event_body_serializer
  #       .add(BigDecimal) { |decimal| decimal.to_s('F') }
  #
  #     # Config how your want to handle event processing errors
  #     config.error_handler_class = EventSourcery::EventProcessing::ErrorHandlers::ExponentialBackoffRetry
  #   end
  #
  def self.configure
    yield config
  end

  def self.config
    @config ||= Config.new
  end

  # Logger object used by EventSourcery. Set via `configure`.
  def self.logger
    config.logger
  end

  # Registry of all ESPs
  def self.event_stream_processor_registry
    @event_stream_processor_registry ||= EventProcessing::EventStreamProcessorRegistry.new
  end
end
