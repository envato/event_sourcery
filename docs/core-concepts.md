# EventSourcery Core Concepts

This document outlines some core concepts in EventSourcery.

Start off by reading about [CQRS](http://martinfowler.com/bliki/CQRS.html), [Event Sourcing](http://www.martinfowler.com/eaaDev/EventSourcing.html), and [Domain-Driven Design](https://en.wikipedia.org/wiki/Domain-driven_design).

**Table of Contents**

- [Tour of an EventSourcery Web Application](#tour-of-an-eventsourcery-web-application)
- [Events](#events)
- [The Event Store](#the-event-store)
    - [Storing Events](#storing-events)
    - [Reading Events](#reading-events)
- [Aggregates and Command Handling](#aggregates-and-command-handling)
- [Event Processing](#event-processing)
    - [Event Stream Processors](#event-stream-processors)
    - [Projectors](#projectors)
    - [Reactors](#reactors)
    - [Running Multiple ESPs](#running-multiple-esps)
- [Typical Flow of State in an Event Sourcery Application](#typical-flow-of-state-in-an-event-sourcery-application)
    - [1. Handling a Command](#1-handling-a-command)
    - [2. Updating a Projection](#2-updating-a-projection)
    - [3. Handling a Query](#3-handling-a-query)

## Tour of an EventSourcery Web Application

Below is a high level view of a CQRS, event-sourced web application built using EventSourcery. The components marked with `*` can be created using building blocks provided by EventSourcery. Keep on reading and we'll describe each of the concepts illustrated.

```
   ┌─────────────┐                        ┌─────────────┐
   │             │                        │             │
   │   Client    │                        │   Client    │
   │             │                        │             │
   └─────────────┘                        └─────────────┘
          │                                      │
    Issue Command                           Issue Query
          │                                      │
  ┌───────┴──────────────────────────────────────┴─────────┐
  │                       Web Layer                        │
  └───────┬──────────────────────────────────────┬─────────┘
          │                                      │
          ▼                                      ▼
   ┌─────────────┐                        ┌─────────────┐
   │   Command   │                        │Query Handler│
   │   Handler   │                        │             │
   └─────────────┘                        └─────────────┘
          │                                      │
          ▼                              ┌───────▼─────┐
   ┌─────────────┐                       │┌────────────┴┐
   │ * Aggregate │                       ││* Projection │
   │             │                       └┤             │
   └─────────────┘                        └─────────────┘
          │                                      ▲
          │                                      │
          │                              Update Projection
          │                                      │
     Emit Event                           ┌─────────────┐
          │                               │┌────────────┴┐
          │                               ││ * Projector │
          ▼                               └┤             │
   ┌─────────────┐                         └─────────────┘
   │* Event Store│       Process                  ▲
┌─▶│             │────────Event───────────────────┘
│  └─────────────┘
│         │
│      Process     ┌─────────────┐
│       Event      │┌────────────┴┐               ┌ ─ ─ ─ ─ ─ ─ ┐
│         └───────▶││  * Reactor  │                  External
│                  └┤             │───Trigger ───▶│   System    │
│                   └─────────────┘  Behaviour     ─ ─ ─ ─ ─ ─ ─
│                          │
│                          │
└────────Emit Event────────┘

```

## Events

Events are value objects that record something of meaning in the domain. Think of a sequence of events as a time series of immutable domain facts.

Events are targeted at an aggregate via an `aggregate_id` and have the following attributes.

```ruby
module EventSourcery
  class Event
    attr_reader \
      :id,             # Sequence number
      :uuid,           # Unique ID
      :aggregate_id,   # ID of aggregate the event pertains to
      :type,           # type of the event
      :body,           # the payload (a hash)
      :version,        # Version of the aggregate
      :created_at,     # Created at date
      :correlation_id  # Correlation ID for tracing purposes

    # ...
  end
end
```

You can define events in your domain as follows.

```ruby
TodoAdded = Class.new(EventSourcery::Event)

# An example instance.
# #<TodoAdded:0x007fb6f88f04b0
#   @id=24,
#   @uuid="75dcc7eb-33c0-4f1c-ac23-31bf32fc5edc",
#   @aggregate_id="fca315ff-d45d-46c5-a230-67c5bec0b06d",
#   @type="todo_added",
#   @body={"title"=>"My task"},
#   @version=1,
#   @created_at=2017-06-14 11:50:32 UTC,
#   @correlation_id="b4d1e31d-9d1b-4ea1-a685-57936ce65a80">
```

## The Event Store

The event store is a persistent store of events.

EventSourcery currently supports a Postgres-based event store via the [event_sourcery-postgres gem](https://github.com/envato/event_sourcery-postgres).

For more information about the `EventStore` API refer to [the postgres event store](https://github.com/envato/event_sourcery-postgres/blob/master/lib/event_sourcery/postgres/event_store.rb) or the [in memory event store in this repo](../lib/event_sourcery/event_store/memory.rb)

### Storing Events

Naturally, it provides the ability to store events. The event store is append-only and immutable. The events in the store form a time-ordered sequence which can be viewed as a stream of events.

`EventStore` clients can optionally provide an expected version of event when saving to the store. This provides a mechanism for `EventStore` clients to effectively serialise the processing they perform against an instance of an aggregate.

When used in this fashion the event store can be thought of as an event sink.

### Reading Events

The `EventStore` also allows clients to read events. Clients can poll the store for events of specific types after a specific event ID. They can also subscribe to the event store to be notified when new events are added to the event store that match the above criteria.

When used in this fashion the event store can be thought of as an event source.

## Aggregates and Command Handling

> An aggregate is a cluster of domain objects that can be treated as a single unit. Every transaction is scoped to a single aggregate. An aggregate will have one of its component objects be the aggregate root. Any references from outside the aggregate should only go to the aggregate root. The root can thus ensure the integrity of the aggregate as a whole.
>
> <cite>— [DDD Aggregate](http://martinfowler.com/bliki/DDD_Aggregate.html)</cite>

Clients execute domain transactions against the system by issuing commands against aggregate roots. The result of these commands is new events being saved to the event store.

A typical EventSourcery application will have one or more aggregate roots with multiple commands.

## Event Processing

A central part of EventSourcery is the processing of events in the store. Event Sourcery provides the Event Stream Processor abstraction to support this.

```
                                           ┌─────────────┐          Subscribe to the event store
                                           │Event Stream │          and take some action. Tracks
                                           │  Processor  │◀─ ─ ─ ─ ─its position in the stream in
                                           │             │           a way that suits its needs.
                                           └─────────────┘
                                                  ▲
                                         ┌────────┴───────────┐
                                         │                    │
                                         │                    │
                                  ┌─────────────┐      ┌─────────────┐
Listens for events and takes      │             │      │             │        Listens for events and
   action. Actions include      ─▶│   Reactor   │      │  Projector  │◀─ ┐     projects data into a
emitting new events into the ─ ┘  │             │      │             │    ─ ─       projection.
store and/or triggering side      └─────────────┘      └─────────────┘
    effects in the world.
```

A typical Event Sourcery application will have multiple projectors and reactors running as background processes.

### Event Stream Processors

Event Stream Processors (ESPs) subscribe to an event store. They read events from the event store and take some action.

When newly created, an ESP will process the event stream from the beginning. When catching up like this an ESP can process events in batches (currently set to 1,000 events). This allows them to optimise processing as desired.

ESPs track the position in the event stream that they've processed in a way that suits them. This allows for them to optimise transaction handling in the case where they are catching up for example.

### Projectors

A Projector is an EventStreamProcessor that listens for events and projects data into a projection. These projections are generally consumed on the read side of the CQRS world.

Projectors tend to be built for specific read-side needs and are generally specific to a single read case.

Modifying a projection is achieved by creating a new projector.

### Reactors

A Reactor is an EventStreamProcessor that listens to events and emits events back into the store and/or trigger side effects in the world.

They typically record any external side effects they've triggered as events in the store.

### Running Multiple ESPs

An EventSourcery application will typically have multiple ESPs running. EventSourcery provides a class called [ESPRunner](../lib/event_sourcery/event_processing/esp_runner.rb) which can be used to run ESPs. It runs each ESP in a forked child process so each ESP can process the event store independently. You can find an example in [event_sourcery_todo_app](https://github.com/envato/event_sourcery_todo_app/blob/master/Rakefile).

Note that you may instead choose to run each ESP in their own process directly. The coordination of this is not currently provided by EventSourcery.

## Typical Flow of State in an Event Sourcery Application

Below we see the typical flow of state in an Event Sourcery application (arrows indicate data flow). Note that steps 1 and 2 are not synchronous. This means Event Sourcery applications need to embrace [eventual consistency](https://en.wikipedia.org/wiki/Eventual_consistency).

```

       1. Issue Command   │      2. Update Projection     │        3. Issue Query

                          │                               │
               │                                                          ▲
               │          │                               │               │
               │                                                          │
               │          │                               │          F. Handle
           B. Handle                                                   Query
            Command       │                               │               │
               │                                                          │
               │          │                               │               │
               ▼                       ┌─────────────┐                    │
        ┌─────────────┐   │            │             │    │        ┌─────────────┐
        │             │       ┌───────▶│  Projector  │             │             │
     ┌─▶│  Aggregate  │   │   │        │             │    │        │Query Handler│
     │  │             │       │        └─────────────┘             │             │
     │  └─────────────┘   │  D. Read          │           │        └─────────────┘
     │         │              event      E. Update                        ▲
 A. Load   C. Emit        │   │          Projection       │               │
state from  Event             │               │                       G. Read
  events       │          │   │               │           │          Projection
     │         ▼              │               ▼                           │
     │  ┌─────────────┐   │   │        ┌─────────────┐    │               │
     │  │             │       │        │             │                    │
     └──│ Event Store │───┼───┘        │ Projection  │────┼───────────────┘
        │             │                │             │
        └─────────────┘   │            └─────────────┘    │

                          │                               │

```

### 1. Handling a Command

A command comes into the application and is routed to a command handler. The command handler initialises an aggregate and loads up its state from events in the store. The command handler then defers to the aggregate to handle the command. It then stores any new events raised by the aggregate into the event store.

```ruby
class AddTodoCommandHandler
  def handle(id:, title:, description:)
    # The repository provides access to the event store for saving and loading aggregates
    repository = EventSourcery::Repository.new(
      event_source: EventSourcery.config.event_source,
      event_sink: EventSourcery.config.event_sink,
    )

    # Load up the aggregate from events in the store
    aggregate = repository.load(TodoAggregate, id)

    # Defer to the aggregate to execute the add command.
    # This may raise new events in the aggregate which we'll need to save.
    aggregate.add(title, description)

    # Save any newly raised events back into the event store
    repository.save(aggregate)
  end
end
```

### 2. Updating a Projection

Projecting is process of converting (or collecting) a stream of events into a structural representation. You can think of the process as a fold over a sequence of events. You can think of a projection as a read model that is generally persisted somewhere like a database table.

A projector is a process that listens for new events in the event store. When it sees a new event it cares about it updates its projection.

```ruby
class OutstandingTodosProjector
  include EventSourcery::Postgres::Projector

  projector_name :outstanding_todos

  # Define our database table projection
  table :outstanding_todos do
    column :todo_id, 'UUID NOT NULL'
    column :title, :text
    column :description, :text
  end

  # Handle TodoAdded events by adding the todo to our projection
  project TodoAdded do |event|
    table.insert(
      todo_id: event.aggregate_id,
      title: event.body['title'],
      description: event.body['description'],
    )
  end

  # Handle TodoCompleted events by removing the todo from our projection
  project TodoCompleted, TodoAbandoned do |event|
    table.where(todo_id: event.aggregate_id).delete
  end
end
```

### 3. Handling a Query

A query comes into the application and is routed to a query handler. The query handler queries the projection directly and returns the result.

```ruby
module OutstandingTodos
  class QueryHandler
    def handle
      EventSourceryTodoApp.projections_database[:outstanding_todos].all
    end
  end
end
```
