# EventSourcery

[![Build Status](https://github.com/envato/event_sourcery/workflows/tests/badge.svg?branch=main)](https://github.com/envato/event_sourcery/actions?query=workflow%3Atests+branch%3Amain)

A framework for building event sourced, CQRS applications.

**Table of Contents**

- [Development Status](#development-status)
- [Goals](#goals)
- [Related Repositories](#related-repositories)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Development](#development)
    - [Dependencies](#dependencies)
    - [Running the Test Suite](#running-the-test-suite)
    - [Release](#release)
- [Core Concepts](#core-concepts)
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
    - [Typical Flow of State in an EventSourcery Application](#typical-flow-of-state-in-an-eventsourcery-application)
        - [1. Handling a Command](#1-handling-a-command)
        - [2. Updating a Projection](#2-updating-a-projection)
        - [3. Handling a Query](#3-handling-a-query)

## Development Status

EventSourcery is currently being used in production by multiple apps but we
haven't finalized the API yet and things are still moving rapidly. Until we
release a 1.0 things may change without first being deprecated.

## Goals

The goal of EventSourcery is to make it easier to build event sourced, CQRS applications.

The hope is that by using EventSourcery you can focus on modeling your domain with aggregates, commands, and events; and not worry about stitching together application plumbing.

## Related Repositories

- EventSourcery's Postgres-based event store implementation: [event_sourcery-postgres](https://github.com/envato/event_sourcery-postgres).
- Example EventSourcery application: [event_sourcery_todo_app](https://github.com/envato/event_sourcery_todo_app).
- An opinionated CLI tool for building event sourced Ruby services with EventSourcery: [event_sourcery_generators](https://github.com/envato/event_sourcery_generators).

## Getting Started

The [example EventSourcery application](https://github.com/envato/event_sourcery_todo_app) is intended to illustrate concepts in EventSourcery, how they relate to each other, and how to use them in practice. If you'd like a succinct look at the library in practice take a look at that.

Otherwise you will generally need to add both event_sourcery and [event_sourcery-postgres](https://github.com/envato/event_sourcery-postgres) to your application.

If Event Sourcing or CQRS is a new concept to you, we highly recommend you watch [An In-Depth Look at Event Sourcing With CQRS](https://www.youtube.com/watch?v=EqpalkqJD8M&t=2680s). It explores some of the theory behind both Event Sourcing & CQRS and will help you better understand the building blocks of the Event Sourcery framework.

## Configuration

There are several ways to configure EventSourcery to your liking. The following presents some examples:

```ruby
EventSourcery.configure do |config|
  # Add custom reporting of errors occurring during event processing.
  # One might set up an error reporting service like Rollbar here.
  config.on_event_processor_error = proc { |exception, processor_name| … }
  config.on_event_processor_critical_error = proc { |exception, processor_name| … }

  # Enable EventSourcery logging.
  config.logger = Logger.new('logs/my_event_sourcery_app.log')

  # Customize how event body attributes are serialized
  config.event_body_serializer
    .add(BigDecimal) { |decimal| decimal.to_s('F') }

  # Config how your want to handle event processing errors
  config.error_handler_class = EventSourcery::EventProcessing::ErrorHandlers::ExponentialBackoffRetry
end
```

## Development

### Dependencies

- Ruby

### Running the Test Suite

Run the `setup` script, inside the project directory to install the gem dependencies and create the test database (if it is not already created).
```bash
./bin/setup
```

Then you can run the test suite with rspec:
```bash
bundle exec rspec
```

### Release

To release a new version:

1. Update the version number in `lib/event_sourcery/version.rb`
2. Add the new version with release notes to CHANGELOG.md
3. Get these changes onto main via the normal PR process
4. Run `bundle exec rake release`, this will create a git tag for the
   version, push tags up to GitHub, and package the code in a `.gem` file.

## Core Concepts

Not sure what Event Sourcing (ES), Command Query Responsibility Segregation (CQRS), or even Domain-Driven Design (DDD) are? Here are a few links to get you started:

- [CQRS and Event Sourcing Talk](https://www.youtube.com/watch?v=JHGkaShoyNs) - by Greg Young at Code on the Beach 2014
- [DDD/CQRS Google Group](https://groups.google.com/forum/#!forum/dddcqrs) - from people new to the concepts to old hands
- [DDD Weekly Newsletter](https://buildplease.com/pages/dddweekly/) - a weekly digest of what's happening in the community
- [Domain-Driven Design](https://www.amazon.com/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215) - the definitive guide
- [Greg Young's Blog](https://goodenoughsoftware.net) - a (the?) lead proponent of all things Event Sourcing

### Tour of an EventSourcery Web Application

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

### Events

Events are value objects that record something of meaning in the domain. Think of a sequence of events as a time series of immutable domain facts. Together they form the source of truth for our application's state.

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

### The Event Store

The event store is a persistent store of events.

EventSourcery currently supports a Postgres-based event store via the [event_sourcery-postgres gem](https://github.com/envato/event_sourcery-postgres).

For more information about the `EventStore` API refer to [the postgres event store](https://github.com/envato/event_sourcery-postgres/blob/HEAD/lib/event_sourcery/postgres/event_store.rb) or the [in memory event store in this repo](lib/event_sourcery/memory/event_store.rb)

#### Storing Events

Naturally, it provides the ability to store events. The event store is append-only and immutable. The events in the store form a time-ordered sequence which can be viewed as a stream of events.

`EventStore` clients can optionally provide an expected version of event when saving to the store. This provides a mechanism for `EventStore` clients to effectively serialise the processing they perform against an instance of an aggregate.

When used in this fashion the event store can be thought of as an event sink.

#### Reading Events

The `EventStore` also allows clients to read events. Clients can poll the store for events of specific types after a specific event ID. They can also subscribe to the event store to be notified when new events are added to the event store that match the above criteria.

When used in this fashion the event store can be thought of as an event source.

### Aggregates and Command Handling

> An aggregate is a cluster of domain objects that can be treated as a single unit. Every transaction is scoped to a single aggregate. An aggregate will have one of its component objects be the aggregate root. Any references from outside the aggregate should only go to the aggregate root. The root can thus ensure the integrity of the aggregate as a whole.
>
> <cite>— [DDD Aggregate](http://martinfowler.com/bliki/DDD_Aggregate.html)</cite>

Clients execute domain transactions against the system by issuing commands against aggregate roots. The result of these commands is new events being saved to the event store.

A typical EventSourcery application will have one or more aggregate roots with multiple commands.

### Event Processing

A central part of EventSourcery is the processing of events in the store. EventSourcery provides the Event Stream Processor abstraction to support this.

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

A typical EventSourcery application will have multiple projectors and reactors running as background processes.

#### Event Stream Processors

Event Stream Processors (ESPs) subscribe to an event store. They read events from the event store and take some action.

When newly created, an ESP will process the event stream from the beginning. When catching up like this an ESP can process events in batches (currently set to 1,000 events). This allows them to optimise processing as desired.

ESPs track the position in the event stream that they've processed in a way that suits them. This allows for them to optimise transaction handling in the case where they are catching up for example.

#### Projectors

A Projector is an EventStreamProcessor that listens for events and projects data into a projection. These projections are generally consumed on the read side of the CQRS world.

Projectors tend to be built for specific read-side needs and are generally specific to a single read case.

Modifying a projection is achieved by creating a new projector.

#### Reactors

A Reactor is an EventStreamProcessor that listens to events and emits events back into the store and/or trigger side effects in the world.

They typically record any external side effects they've triggered as events in the store.

Reactors can be used to build [process managers or sagas](https://msdn.microsoft.com/en-us/library/jj591569.aspx).

#### Running Multiple ESPs

An EventSourcery application will typically have multiple ESPs running. EventSourcery provides a class called [ESPRunner](lib/event_sourcery/event_processing/esp_runner.rb) which can be used to run ESPs. It runs each ESP in a forked child process so each ESP can process the event store independently. You can find an example in [event_sourcery_todo_app](https://github.com/envato/event_sourcery_todo_app/blob/HEAD/Rakefile).

Note that you may instead choose to run each ESP in their own process directly. The coordination of this is not currently provided by EventSourcery.

### Typical Flow of State in an EventSourcery Application

Below we see the typical flow of state in an EventSourcery application (arrows indicate data flow). Note that steps 1 and 2 are not synchronous. This means EventSourcery applications need to embrace [eventual consistency](https://en.wikipedia.org/wiki/Eventual_consistency).

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

#### 1. Handling a Command

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

#### 2. Updating a Projection

You can think of projections as read-only models. They are created and updated by projectors and show different views over the events that are the source of truth for our application state. Projections are typically stored as database tables.

Projecting is process of converting (or collecting) a stream of events into these database tables. You can think of this process as a fold over a sequence of events.

A projector is a process that listens for new events in the event store. When it sees a new event it cares about it updates its projection.

```ruby
class OutstandingTodosProjector
  include EventSourcery::Postgres::Projector

  projector_name :outstanding_todos

  # Database table that forms the projection.
  table :outstanding_todos do
    column :todo_id, 'UUID NOT NULL'
    column :title, :text
    column :description, :text
  end

  # Handle TodoAdded events by adding the todo to our projection.
  project TodoAdded do |event|
    table.insert(
      todo_id: event.aggregate_id,
      title: event.body['title'],
      description: event.body['description'],
    )
  end

  # Handle TodoCompleted events by removing the todo from our projection.
  project TodoCompleted, TodoAbandoned do |event|
    table.where(todo_id: event.aggregate_id).delete
  end
end
```

#### 3. Handling a Query

A query comes into the application and is routed to a query handler. The query handler queries the projection directly and returns the result.

```ruby
module OutstandingTodos
  # Query handler that queries the projection table.
  class QueryHandler
    def handle
      EventSourceryTodoApp.projections_database[:outstanding_todos].all
    end
  end
end
```
