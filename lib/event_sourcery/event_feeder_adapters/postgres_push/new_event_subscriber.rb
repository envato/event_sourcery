module EventSourcery
  module EventFeederAdapters
    class PostgresPush
      class NewEventSubscriber
        EarlyStopError = Class.new(StandardError)

        def initialize(sequel_connection)
          @sequel_connection = sequel_connection
        end

        def listen(loop: true, after_listen: nil, timeout: 30, &block)
          @callback = block
          @after_listen = after_listen
          @sequel_connection.listen('new_event',
                                    loop: loop,
                                    after_listen: method(:after_listen_callback),
                                    timeout: @timeout) do |channel, pid, payload|
            new_event_id = Integer(payload)
            @callback.call(new_event_id)
          end
        rescue EarlyStopError
        end

        private

        def after_listen_callback(pg_conn)
          notify_last_event
          @after_listen.call if @after_listen
        end

        def notify_last_event
          last_event = @sequel_connection[:events].order(:id).select(:id).last
          last_event_id = if last_event
                            last_event[:id]
                          end
          notify_event(last_event_id) if last_event_id
        end

        # Since this is called through Postgress after_listen callback, it doesn't
        # have the catch(:stop) block. We're re-implementing that behaviour to be
        # able to stop the listener in the first callback and make it consistent.
        def notify_event(event_id)
          result = catch(:stop) do
            @callback.call(event_id)
            :succeeded
          end
          raise EarlyStopError if result != :succeeded
        end
      end
    end
  end
end
