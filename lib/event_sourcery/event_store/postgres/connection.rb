module EventSourcery
  module EventStore
    module Postgres
      class Connection
        include EachByRange

        def initialize(pg_connection, events_table_name: EventSourcery.config.events_table_name, lock_table: EventSourcery.config.lock_table_to_guarantee_linear_sequence_id_growth, event_builder: EventSourcery.config.event_builder)
          @pg_connection = pg_connection
          @events_table_name = events_table_name
          @lock_table = lock_table
          @event_builder = event_builder
        end

        def sink(event_or_events)
          events = Array(event_or_events)
          maybe_lock_table do
            events.each do |event|
              result = events_table.
                returning(:id).
                insert(aggregate_id: event.aggregate_id,
                       type: event.type.to_s,
                       body: ::Sequel.pg_json(event.body),
                       uuid: event.uuid)
              event_id = result.first.fetch(:id)
              @pg_connection.notify('new_event', payload: event_id)
              EventSourcery.logger.debug { "Saved event: #{event.inspect}" }
            end
            true
          end
        end

        def get_next_from(id, event_types: nil, limit: 1000)
          query = events_table.
            order(:id).
            where('id >= :from_id',
                  from_id: id).
            limit(limit)
          if event_types
            query = query.where(type: event_types)
          end
          query.map do |event_row|
            build_event(event_row)
          end
        end

        def latest_event_id(event_types: nil)
          latest_event = events_table
          if event_types
            latest_event = latest_event.where(type: event_types)
          end
          latest_event = latest_event.order(:id).last
          if latest_event
            latest_event[:id]
          else
            0
          end
        end

        def get_events_for_aggregate_id(id)
          events_table.where(aggregate_id: id.to_str).order(:id).map do |event_hash|
            build_event(event_hash)
          end
        end

        def subscribe(from_id:, event_types: nil, after_listen: nil, subscription_master:, &block)
          poll_waiter = OptimisedEventPollWaiter.new(pg_connection: @pg_connection, after_listen: after_listen)
          args = {
            poll_waiter: poll_waiter,
            event_store: self,
            from_event_id: from_id,
            event_types: event_types,
            events_table_name: @events_table_name,
            subscription_master: subscription_master,
            on_new_events: block
          }
          Subscription.new(args).tap do |s|
            s.start
          end
        end

        private

        def events_table
          @pg_connection[@events_table_name]
        end

        def maybe_lock_table
          if @lock_table
            @pg_connection.transaction do
              @pg_connection.execute "lock #{@events_table_name} in exclusive mode;"
              yield
            end
          else
            yield
          end
        end

        def build_event(data)
          @event_builder.build(data)
        end
      end
    end
  end
end
