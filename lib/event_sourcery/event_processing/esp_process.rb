module EventSourcery
  module EventProcessing
    class ESPProcess
      def initialize(event_processor:,
                     event_store:,
                     on_event_processor_error:,
                     stop_on_failure:,
                     subscription_master: EventStore::SubscriptionMaster.new)
        @event_processor = event_processor
        @event_store = event_store
        @on_event_processor_error = on_event_processor_error
        @stop_on_failure = stop_on_failure
        @subscription_master = subscription_master
      end

      def start
        with_error_handling do
          with_logging do
            name_process
            setup_graceful_shutdown
            subscribe_to_event_stream
          end
        end
      end

      private

      def name_process
        Process.setproctitle(@event_processor.class.name)
      end

      def setup_graceful_shutdown
        %i(TERM INT).each do |signal|
          Signal.trap(signal) { @subscription_master.request_shutdown }
        end
      end

      def subscribe_to_event_stream
        @event_processor.subscribe_to(@event_store,
                                      subscription_master: @subscription_master)
      end

      def with_error_handling
        yield
      rescue => error
        report_error(error)
        sleep(1) && retry unless @stop_on_failure
      end

      def report_error(error)
        EventSourcery.logger.error do
          "Processor #{@event_processor.processor_name} died with #{error}.\n"\
          "#{e.backtrace.join("\n")}"
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
