module EventSourcery
  module EventStore
    module Postgres
      # Optimise poll interval with Postgres listen/notify
      class OptimisedEventPollWaiter
        def initialize(pg_connection:, timeout: 30, after_listen: proc { })
          @pg_connection = pg_connection
          @timeout = timeout
          @events_queue = ::Queue.new
          @after_listen = after_listen
        end

        def poll(after_listen: proc { }, &block)
          start_async(after_listen: after_listen)
          catch(:stop) {
            block.call
            loop do
              break if !@listen_thread.alive?
              wait_for_new_event_to_appear
              clear_new_event_queue
              block.call
            end
          }
        end

        private

        def wait_for_new_event_to_appear
          @events_queue.pop
        end

        def clear_new_event_queue
          @events_queue.clear
        end

        def start_async(after_listen: nil)
          after_listen_callback = if after_listen
                                    proc {
                                      after_listen.call
                                      @after_listen.call if @after_listen
                                    }
                                  else
                                    @after_listen
                                  end
          @listen_thread = Thread.new { listen_for_new_events(loop: true,
                                                              after_listen: after_listen_callback,
                                                              timeout: @timeout) }
        end

        def listen_for_new_events(loop: true, after_listen: nil, timeout: 30)
          @pg_connection.listen('new_event',
                                loop: loop,
                                after_listen: after_listen,
                                timeout: timeout) do |_channel, _pid, _payload|
            if @events_queue.empty?
              @events_queue.push(:new_event_arrived)
            end
          end
        end
      end
    end
  end
end
