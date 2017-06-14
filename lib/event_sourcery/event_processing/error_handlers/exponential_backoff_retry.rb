module EventSourcery
  module EventProcessing
    module ErrorHandlers
      class ExponentialBackoffRetry
        include EventSourcery::EventProcessing::ErrorHandlers::ErrorHandler
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
          update_retry_interval(error)
          sleep(@retry_interval)
          retry
        end

        private

        def update_retry_interval(error)
          if error.instance_of?(EventSourcery::EventProcessingError)
            if @error_event_uuid == error.event.uuid
              @retry_interval *= 2 if @retry_interval < MAX_RETRY_INVERVAL
            else
              @error_event_uuid = error.event.uuid
              @retry_interval = DEFAULT_RETRY_INVERAL
            end
          else
            @retry_interval = DEFAULT_RETRY_INVERAL
          end
        end
      end
    end
  end
end
