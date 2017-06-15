# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
- The core Event class accepts `causation_id` to allow event stores to
  add support for tracking causation ids with events.

### Removed
- The `processing_event` method from the memory tracker. It was intended to
  be a mechanism to wrap processing and tracker updates which appears to be
  universally unused at this point.

## [0.12.0] - 2017-6-1
### Removed
- Removed usage `#shutdown!` as it should be a private method within custom PollWaiters.
  An example of how event_sourcery-postgres has implemented `#shutdown!` can be
  found [here](https://github.com/envato/event_sourcery-postgres/pull/5)

## [0.11.2] - 2017-5-29
### Fixed
- Fixed: default poll waiter now implements `shutdown!`

## [0.11.0] - 2017-5-29
### Fixed
- Use `processor.class.name` to set ESP process name
- Convert `processor_name` symbol to string explicitly

## [0.11.0] - 2017-5-26
### Added
- Make Event processing error handler class Configurable
- Add exponential back off retry error handler

## [0.10.0] - 2017-5-24
### Added
- The core Event class accepts `correlation_id` to allow event stores to
  add support for tracking correlation IDs with events.
- `Repository#save` for saving aggregate instances.
- Configuration option to define custom event body serializers.

### Fixed
- Resolved Sequel deprecation notice when loading events from the Postgres event
  store.

### Changed
- Aggregates no longer save events directly to an event sink. They must be
  passed back to the repository for saving with `repository.save(aggregate)`.
- `AggregateRoot#apply_event` signature has changed from accepting an event or
  a hash to accepting an event class followed by what would normally go in the
  constructor of the event.

### Removed
- Postgres specific code has moved to the [event_sourcery-postgres](https://github.com/envato/event_sourcery-postgres) gem.
  Config options for postgres have moved to `EventSourcery::Postgres.config`.

## [0.9.0] - 2017-05-02
### Added
- Add `table_prefix` method to `TableOwner` to declare a table name prefix for
  all tables in a projector or reactor.

### Changed
- Schema change: the `writeEvents` function has been refactored slightly.
- The `Event` class no longer uses `Virtus.value_object`.
- `AggregateRoot` and `Repository` are namespaced under `EventSourcery` instead
  of `EventSourcery::Command`.
- `EventSourcery::Postgres` namespace has been extracted from
  `EventSourcery::(EventStore|EventProcessing)::Postgres` in preparation for
moving all Postgres related code into a separate gem.
- An advisory lock has replaced the exclusive table lock used to synchronise
  event inserts.

### Removed
- EventSourcery no longer depends on Virtus.
- `Command` and `CommandHandler` have been removed.
