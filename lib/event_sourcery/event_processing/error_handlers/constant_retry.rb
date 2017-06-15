module EventSourcery
  module EventProcessing
    module ErrorHandlers
      # Module which includes multiple ways of error handling.
      class ConstantRetry
        include EventSourcery::EventProcessing::ErrorHandlers::ErrorHandler

        # The retry interval.
        #
        # @api private
        DEFAULT_RETRY_INVERAL = 1
        
        def initialize(processor_name:)
          @processor_name = processor_name
          @retry_interval = DEFAULT_RETRY_INVERAL
        end

        # Will yeild the black and attempt to retry after a defined retry interval.
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
