module EventSourcery
  module EventProcessing
    module ErrorHandlers
      class NoRetry
        include EventSourcery::EventProcessing::ErrorHandlers::ErrorHandler

        def with_error_handling
          yield
        rescue => error
          report_error(error)
          Process.exit(false)
        end
      end
    end
  end
end
