# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
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