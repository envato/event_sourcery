module EventSourcery
  module EventProcessing
    class ESPProcessErrorHandler
      DEFAULT_RETRY_INVERAL = 1
      MAX_RETRY_INVERVAL = 64
      def initialize(processor_name:,
                     retry_strategy: EventSourcery.config.retry_strategy,
                     on_event_processor_error: EventSourcery.config.on_event_processor_error
                    )
        @processor_name = processor_name
        @retry_strategy = retry_strategy
        @on_event_processor_error = on_event_processor_error
        @retry_interval = DEFAULT_RETRY_INVERAL
      end

      def handle(error)
        report_error(error)

        if retry?
          if @retry_strategy == :exponential && error.instance_of?(EventSourcery::EventProcessingError)
            update_retry_interval(error)
          else
            @retry_interval = DEFAULT_RETRY_INVERAL
          end

          sleep(@retry_interval)
        end

      end

      def retry?
        @retry_strategy != :never
      end
      
      private

      def update_retry_interval(error)
        if @error_event_uuid == error.event.uuid && @retry_interval < MAX_RETRY_INVERVAL
          @retry_interval *=2
        else
          @error_event_uuid = error.event.uuid
          @retry_interval = DEFAULT_RETRY_INVERAL
        end
      end

      def report_error(error)
        error = error.original_error if error.instance_of?(EventSourcery::EventProcessingError)
        EventSourcery.logger.error do
          "Processor #{@processor_name} died with #{error}.\n"\
          "#{error.backtrace.join("\n")}"
        end
        @on_event_processor_error.call(error, @processor_name)
      end
    end
  end
end
