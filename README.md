# EventSourcery

## Event Store

```ruby
# Convenient way to build a specific world view
store = EventSourcery::EventStore.new(:postgres, db_connection)

# Or construct each adapter manually
store = EventSourcery::EventStore.new do |config|
  config.event_source = EventSourcery::EventSourceAdapters::Postgres.new(pg_connection)
  config.event_sink = EventSourcery::EventSinkAdapters::Postgres.new(pg_connection)
  config.event_publisher = EventSourcery::EventPublisherAdapters::PostgresPush.new(pg_connection)
end
```

### Saving events

```ruby
user_id = SecureRandom.uuid
store.sink(aggregate_id: user_id, type: :signed_up, body: { email: 'me@example.com' })
```

### Reading events

```ruby
# get raw events
events = store.get_events_for_aggregate_id(user_id)
```

### Subscribing to events

```ruby
publisher = store.publisher

publisher.add_subscription(0) do |event|
  processor_1.process(event)
end
publisher.add_subscription(0, types: [:name_changed]) do |event|
  processor_2.process(event)
end
publisher.start! # block and start feeding events
```

## Event Processors

### Projectors

```ruby
class UserProjector
  include EventSourcery::Projector
  self.processor_name = 'users'
  processes_events :signup

  table :users do
    column :uuid, 'UUID NOT NULL'
    column :name, 'VARCHAR(255) NOT NULL'
    column :email, 'VARCHAR(255) NOT NULL'
  end

  def process(event)
    table.insert(event.aggregate_uuid, event.body[:name], event.body[:email])
  end
end
```

### Downstream Event Processors

```ruby
class WelcomeEmailDownstreamEventProcessor
  include EventSourcery::DownstreamEventProcessor
  self.processor_name = 'welcome_email'
  processes_events :signup
  emits_events :welcome_email_sent

  def process(event)
    name = event.body[:name]
    email = event.body[:email]
    UserMailer.deliver_welcome_email(name, email)
    emit_event(type: :welcome_email_sent, aggregate_id: event.aggregate_id) do |body|
      body[:sent_to] = email
      body[:sent_at] = Time.now
    end
  end
end
```

# Roadmap/TODO

```ruby
user_aggregate = EventSourcery::AggregateRepository.load(User, user_id)
```
