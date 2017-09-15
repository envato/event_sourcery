module EventSourcery
  module EventProcessing
    module ErrorHandlers
      # Strategies for error handling.
      class ConstantRetry
        include EventSourcery::EventProcessing::ErrorHandlers::ErrorHandler

        # The retry interval used with {with_error_handling}.
        #
        # @api private
        DEFAULT_RETRY_INTERVAL = 1
        
        def initialize(processor_name:)
          @processor_name = processor_name
          @retry_interval = DEFAULT_RETRY_INTERVAL
        end

        # Will yield the block and attempt to retry after a defined retry interval {DEFAULT_RETRY_INTERVAL}.
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
