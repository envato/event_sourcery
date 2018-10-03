module EventSourcery
  module EventProcessing
    class ESPProcess
      DEFAULT_AFTER_FORK = -> (event_processor) { }

      def initialize(event_processor:,
                     event_source:,
                     subscription_master: EventStore::SignalHandlingSubscriptionMaster.new,
                     after_fork: nil)
        @event_processor = event_processor
        @event_source = event_source
        @subscription_master = subscription_master
        @after_fork = after_fork || DEFAULT_AFTER_FORK
      end

      # This will start the Event Stream Processor which will subscribe
      # to the event stream source.
      def start
        name_process
        @after_fork.call(@event_processor)
        error_handler.with_error_handling do
          EventSourcery.logger.info("Starting #{processor_name}")
          subscribe_to_event_stream
          EventSourcery.logger.info("Stopping #{processor_name}")
        end
      rescue Exception => e
        EventSourcery.logger.fatal("An unhandled exception occurred in #{processor_name}")
        EventSourcery.logger.fatal(e)
        EventSourcery.config.on_event_processor_error.call(e, processor_name)
        raise e
      end

      private

      def processor_name
        @event_processor.processor_name.to_s
      end

      def error_handler
        @error_handler ||= EventSourcery.config.error_handler_class.new(processor_name: processor_name)
      end

      def name_process
        Process.setproctitle(@event_processor.class.name)
      end

      def subscribe_to_event_stream
        @event_processor.subscribe_to(@event_source,
                                      subscription_master: @subscription_master)
      end
    end
  end
end
