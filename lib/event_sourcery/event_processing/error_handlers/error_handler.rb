module EventSourcery
  module EventProcessing
    module ErrorHandlers
      module ErrorHandler
        def with_error_handling
          raise NotImplementedError, 'Please implement #with_error_handling method'
        end
        
        private

        def report_error(error)
          error = error.original_error if error.instance_of?(EventSourcery::EventProcessingError)
          EventSourcery.logger.error("Processor #{@processor_name} died with #{error}.\\n #{error.backtrace.join('\n')}")

          EventSourcery.config.on_event_processor_error.call(error, @processor_name)
        end
      end
    end
  end
end
