module EventSourcery
  module EventProcessing
    module ErrorHandlers
      class ConstantRetry
        include EventSourcery::EventProcessing::ErrorHandlers::ErrorHandler
        DEFAULT_RETRY_INVERAL = 1
        def initialize(processor_name:)
          @processor_name = processor_name
          @retry_interval = DEFAULT_RETRY_INVERAL
        end

        def with_error_handling
          yield
        rescue => error
          report_error(error)
          sleep(@retry_interval)

          retry
        end
      end
    end
  end
end
