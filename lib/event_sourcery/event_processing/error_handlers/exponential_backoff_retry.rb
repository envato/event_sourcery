module EventSourcery
  module EventProcessing
    module ErrorHandlers
      class ExponentialBackoffRetry
        DEFAULT_RETRY_INVERAL = 1
        MAX_RETRY_INVERVAL = 64
        def initialize(processor_name:)
          @processor_name = processor_name
          @retry_interval = DEFAULT_RETRY_INVERAL
        end

        def with_error_handling
          yield
        rescue => error
          report_error(error)

          if error.instance_of?(EventSourcery::EventProcessingError)
            update_retry_interval(error)
          else
            @retry_interval = DEFAULT_RETRY_INVERAL
          end

          sleep(@retry_interval)
          retry
        end
        
        private

        def update_retry_interval(error)
          if @error_event_uuid == error.event.uuid
            @retry_interval *=2 if @retry_interval < MAX_RETRY_INVERVAL
          else
            @error_event_uuid = error.event.uuid
            @retry_interval = DEFAULT_RETRY_INVERAL
          end
        end

        def report_error(error)
          error = error.original_error if error.instance_of?(EventSourcery::EventProcessingError)
          EventSourcery.logger.error("Processor #{@processor_name} died with #{error}.\\n #{error.backtrace.join('\n')}")

          EventSourcery.config.on_event_processor_error.call(error, @processor_name)
        end
      end
    end
  end
end
