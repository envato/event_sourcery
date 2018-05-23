module EventSourcery
  module EventStore

    # This allows Event Stream Processors (ESPs) to subscribe to an event store, and be notified when new events are
    # added.
    class Subscription
      #
      # @param event_store Event store to source events from
      # @param poll_waiter Poll waiter instance used (such as {EventStore::PollWaiter}) for polling the event store
      # @param from_event_id [Integer] Start reading events from this event ID
      # @param event_types [Array] Optional. If specified, only subscribe to given event types.
      # @param on_new_events [Proc] Code block to be executed when new events are received
      # @param subscription_master A subscription master instance (such as {EventStore::SignalHandlingSubscriptionMaster}) which orchestrates a graceful shutdown of the subscription, if one is requested.
      # @param events_table_name [Symbol] Optional. Defaults to `:events`
      def initialize(event_store:,
                     poll_waiter:,
                     from_event_id:,
                     event_types: nil,
                     on_new_events:,
                     subscription_master:,
                     events_table_name: :events,
                     batch_size: EventSourcery.config.subscription_batch_size)
        @event_store = event_store
        @from_event_id = from_event_id
        @poll_waiter = poll_waiter
        @event_types = event_types
        @on_new_events = on_new_events
        @subscription_master = subscription_master
        @current_event_id = from_event_id - 1
        @batch_size = batch_size
      end

      # Start listening for new events. This method will continue to listen for new events until a shutdown is requested
      # through the subscription_master provided.
      #
      # @see EventStore::SignalHandlingSubscriptionMaster
      def start
        catch(:stop) do
          @poll_waiter.poll do
            read_events
          end
        end
      end

      private

      attr_reader :batch_size

      def read_events
        loop do
          @subscription_master.shutdown_if_requested
          events = @event_store.get_next_from(@current_event_id + 1, event_types: @event_types, limit: batch_size)
          break if events.empty?
          EventSourcery.logger.debug { "New events in subscription: #{events.inspect}" }
          @on_new_events.call(events)
          @current_event_id = events.last.id
          EventSourcery.logger.debug { "Position in stream: #{@current_event_id}" }
        end
      end
    end
  end
end
