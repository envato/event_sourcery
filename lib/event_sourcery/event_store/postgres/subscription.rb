module EventSourcery
  module EventStore
    module Postgres
      class Subscription
        def initialize(pg_connection:,
                       event_types: nil,
                       on_new_event:,
                       events_table_name: :events)
          @pg_connection = pg_connection
          @event_types = event_types
          @on_new_event = on_new_event
          @events_queue = ::Queue.new
        end

        def start(after_listen: nil, timeout: 30)
          start_async(after_listen: after_listen, timeout: timeout)
          catch(:stop) {
            loop do
              break if !@listen_thread.alive?
              @on_new_event.call(@events_queue.pop)
            end
          }
        end

        def start_async(after_listen: nil, timeout: 30)
          @listen_thread = Thread.new { listen_for_new_events(loop: true,
                                                              after_listen: after_listen,
                                                              timeout: timeout) }
        end

        private

        def listen_for_new_events(loop: true, after_listen: nil, timeout: 30)
          @after_listen = after_listen
          @pg_connection.listen('new_event',
                                loop: loop,
                                after_listen: after_listen,
                                timeout: @timeout) do |channel, pid, payload|
            new_event_id = Integer(payload)
            new_event = load_event(new_event_id)
            @events_queue.push(new_event)
          end
        end

        def load_event(event_id)
          return if event_id.nil?
          event_hash = @pg_connection[:events].where(id: event_id).order(:id).first
          Event.new(event_hash)
        end
      end
    end
  end
end
