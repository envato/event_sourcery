module EventSourcery
  module EventProcessing
    module ErrorHandlers
      class ConstantRetry
        include EventSourcery::EventProcessing::ErrorHandlers::ErrorHandler

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
