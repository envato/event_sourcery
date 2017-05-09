module EventSourcery
  module EventProcessing
    class ESPProcess
      def initialize(event_processor:,
                     event_store:,
                     subscription_master: EventStore::SignalHandlingSubscriptionMaster.new
                    )
        @event_processor = event_processor
        @event_store = event_store
        @subscription_master = subscription_master
      end

      def start
        name_process
        begin
          EventSourcery.logger.info("Starting #{processor_name}")
          subscribe_to_event_stream
        rescue => error
          error_handler.handle(error)
          retry if error_handler.retry?
        ensure
          EventSourcery.logger.info("Stopping #{processor_name}")
          Process.exit(false)
        end
      end

      private

      def processor_name
        @event_processor.processor_name
      end

      def error_handler
        @error_handler ||= ESPProcessErrorHandler.new(processor_name: processor_name)
      end

      def name_process
        Process.setproctitle(processor_name)
      end

      def subscribe_to_event_stream
        @event_processor.subscribe_to(@event_store,
                                      subscription_master: @subscription_master)
      end
    end
  end
end
