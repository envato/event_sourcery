module EventSourcery
  module EventProcessing
    module ErrorHandlers
      class NoRetry
        include EventSourcery::EventProcessing::ErrorHandlers::ErrorHandler
        def initialize(processor_name:)
          @processor_name = processor_name
        end

        # Will yield the block and exit the process if an error is raised.
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
