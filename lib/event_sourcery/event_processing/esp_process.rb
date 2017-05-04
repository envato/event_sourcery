module EventSourcery
  module EventProcessing
    class ESPProcess
      def initialize(event_processor:,
                     event_store:,
                     on_event_processor_error: EventSourcery.config.on_event_processor_error,
                     stop_on_failure:,
                     subscription_master: EventStore::SignalHandlingSubscriptionMaster.new,
                     retry_strategy: EventSourcery.config.retry_strategy
                    )
        @event_processor = event_processor
        @event_store = event_store
        @on_event_processor_error = on_event_processor_error
        @stop_on_failure = stop_on_failure
        @subscription_master = subscription_master
        @retry_strategy = retry_strategy
        @retry_interval = 1
        @max_retry_interval = 64
      end

      def start
        with_error_handling do
          with_logging do
            name_process
            subscribe_to_event_stream
          end
        end
      end

      private

      def name_process
        Process.setproctitle(@event_processor.class.name)
      end

      def subscribe_to_event_stream
        @event_processor.subscribe_to(@event_store,
                                      subscription_master: @subscription_master)
      end

      def with_error_handling
        yield
        @retry_interval = 1
      rescue => error
        report_error(error)
        if @stop_on_failure
          Process.exit(false)
        else
          sleep(@retry_interval)
          update_retry_interval
          retry
        end
      end

      def update_retry_interval
        if @retry_strategy == :exponential && @retry_interval < @max_retry_interval
          @retry_interval *=2
        end
      end

      def report_error(error)
        EventSourcery.logger.error do
          "Processor #{@event_processor.processor_name} died with #{error}.\n"\
          "#{error.backtrace.join("\n")}"
        end
        @on_event_processor_error.call(error, @event_processor.processor_name)
      end

      def with_logging
        EventSourcery.logger.info do
          "Starting #{@event_processor.processor_name}"
        end
        yield
        EventSourcery.logger.info do
          "Stopping #{@event_processor.processor_name}"
        end
      end
    end
  end
end
