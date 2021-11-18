# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
## [0.24.0] - 2021-11-18

### Added

- Test against Ruby 3.0 in the CI build ([#229]).

### Changed

- Use GitHub Actions for the CI build instead of Travis CI ([#228]).
- This project now uses `main` as its default branch ([#230]).
  - Documentation updated to refer to `main` and links updated accordingly.

### Removed
- Remove Ruby 2.3, 2.4 and 2.5 from the CI test matrix ([#232]).

[#228]: https://github.com/envato/event_sourcery/pull/228
[#229]: https://github.com/envato/event_sourcery/pull/229
[#230]: https://github.com/envato/event_sourcery/pull/230
[#232]: https://github.com/envato/event_sourcery/pull/232

## [0.23.1] - 2020-10-02
### Fixed
- Upgrade development dependency Rake to version 13. This resolves
  [CVE-2020-8130](https://github.com/advisories/GHSA-jppv-gw3r-w3q8).

- Patch `ESPRunner` to gracefully handle terminating subprocesses it did
  not start ([#223]).

- Resolve warnings raised by Ruby 2.7 ([#225]).

[#223]: https://github.com/envato/event_sourcery/pull/223
[#225]: https://github.com/envato/event_sourcery/pull/225

## [0.23.0] - 2019-07-11
### Added
- Add Ruby 2.6 to the CI test matrix.
- `ESPRunner` supports an `after_subprocess_termination` hook. This optional
  initializer argument will will be executed when each child process
  terminates. This allows for monitoring and alerts to be configured.
  For example, Rollbar:

  ```ruby
  EventSourcery::EventProcessing::ESPRunner.new(
    event_processors: processors,
    event_source: source,
    after_subprocess_termination: proc do |processor:, runner:, exit_status:|
      if exit_status != 0
        Rollbar.error("Processor #{processor.processor_name} "\
                      "terminated with exit status #{exit_status}")
      end
    end
  ).start!
  ```

- `ESPRunner` exposes three new public methods `start_processor`, `shutdown`,
  and `shutdown_requested?`. These provide options for handling subprocess
  failure/termination. For example, shutting down the `ESPRunner`:

  ```ruby
  EventSourcery::EventProcessing::ESPRunner.new(
    event_processors: processors,
    event_source: source,
    after_subprocess_termination: proc do |processor:, runner:, exit_status:|
      runner.shutdown
    end
  ).start!
  ```

  Or restarting the event processor:

  ```ruby
  EventSourcery::EventProcessing::ESPRunner.new(
    event_processors: processors,
    event_source: source,
    after_subprocess_termination: proc do |processor:, runner:, exit_status:|
      runner.start_processor(processor) unless runner.shutdown_requested?
    end
  ).start!
  ```

- `ESPRunner` checks for dead child processes every second. This means we
  shouldn't see `[ruby] <defunct>` in the process list (ps) when a processor
  fails.
- `ESPRunner` logs when child processes die.
- `ESPRunner` logs when sending signals to child processes.

### Removed
- Remove Ruby 2.2 from the CI test matrix.

## [0.22.0] - 2018-10-04
### Added
- Log critical exceptions to the application provided block via the new
  configuration option ([#209](https://github.com/envato/event_sourcery/pull/209)):

  ```ruby
  config.on_event_processor_critical_error = proc do |exception, processor_name|
    # report the death of this processor to an error reporting service like Rollbar.
  end
  ```

## [0.21.0] - 2018-07-02
### Added
- Graceful shutdown interrupts poll-wait sleep for quicker quitting
  ([#207](https://github.com/envato/event_sourcery/pull/207)).
- Added `bug_tracker_uri`, `changelog_uri` and `source_code_uri` to project
  metadata ([#205](https://github.com/envato/event_sourcery/pull/205)).

### Changed
- Fixed a bug where ESPRunner would raise an error under certain circumstances
  ([#203](https://github.com/envato/event_sourcery/pull/203)).

## [0.20.0] - 2018-06-21
### Changed
- Changed signature of `ESPProcess#initialize` to include a default value for `after_fork`. This prevents the
`after_fork` change from 0.19.0 from being a breaking change to external creators of ESPProcess.
- Added more logging when a fatal exception occurs in ESPProcess

## [0.19.0] - 2018-06-06
### Added

- Allow passing an `after_fork` lambda to `ESPRunner` that is called after each
  `ESPProcess` is forked

## [0.18.0] - 2018-05-23

- Allow specifying a subscription batch size

## [0.17.0] - 2018-03-22
### Added
- Allow changing the event class using Event#with
- Allow upcasting events using custom event classes

## [0.16.1] - 2018-01-17
- Fixed bug with Sequel gem expecting processes_event_types to be an Array

## [0.16.0] - 2018-01-02
### Added
- Added additional logging for retries to the ExponentialBackoffRetry error handler
- Remove `processes_events` and related methods in favour of `process` class
  method. You can no longer override `process` and subscribe to all events.
  If you want to subscribe to all events you can call the `process` class
  method with no events.

      process do |event|
        # all events will be subscribed to
      end

      process Foobar do |event|
        # Foobar events will be subscribed to
      end

## [0.15.0] - 2017-11-29
### Added
- Added in the first version of the yard documentation.

### Changed
- Improved EventProcessingError messages
- Fixed typo in constant name `EventSourcery::EventProcessing::ErrorHandlers::ConstantRetry::DEFAULT_RETRY_INTERVAL`
- Fixed typo in constant name `EventSourcery::EventProcessing::ErrorHandlers::ExponentialBackoffRetry::DEFAULT_RETRY_INTERVAL`
- Fixed typo in constant name `EventSourcery::EventProcessing::ErrorHandlers::ExponentialBackoffRetry::MAX_RETRY_INTERVAL`
- Errors of type `Exception` are now logged before being allowed to propagate.

## [0.14.0] - 2016-06-21
### Added
- Added `Event#to_h` method. This returns a hash of the event attributes.
- Added `Event#with` method. This provides a way to create a new event
  identical to the old event except for the provided changes.
- `Event#initialize` accepts `aggregate_id` parameter that either is
  a strings or responds to `to_str`.

## [0.13.0] - 2016-06-16
### Added
- The core Event class accepts `causation_id` to allow event stores to
  add support for tracking causation ids with events.
- The core Memory event store saves the `causation_id` and `correlation_id`.

### Changed
- The event store shared RSpec examples specify event stores should save
  the `causation_id` and `correlation_id`.

### Removed
- The `processing_event` method from the memory tracker. It was intended to
  be a mechanism to wrap processing and tracker updates which appears to be
  universally unused at this point.

## [0.12.0] - 2017-06-01
### Removed
- Removed usage `#shutdown!` as it should be a private method within custom PollWaiters.
  An example of how event_sourcery-postgres has implemented `#shutdown!` can be
  found [here](https://github.com/envato/event_sourcery-postgres/pull/5)

## [0.11.2] - 2017-05-29
### Fixed
- Fixed: default poll waiter now implements `shutdown!`

## [0.11.1] - 2017-05-29
### Fixed
- Use `processor.class.name` to set ESP process name
- Convert `processor_name` symbol to string explicitly

## [0.11.0] - 2017-05-26
### Added
- Make Event processing error handler class Configurable
- Add exponential back off retry error handler

## [0.10.0] - 2017-05-24
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

[Unreleased]: https://github.com/envato/event_sourcery/compare/v0.24.0...HEAD
[0.24.0]: https://github.com/envato/event_sourcery/compare/v0.23.1...v0.24.0
[0.23.1]: https://github.com/envato/event_sourcery/compare/v0.23.0...v0.23.1
[0.23.0]: https://github.com/envato/event_sourcery/compare/v0.22.0...v0.23.0
[0.22.0]: https://github.com/envato/event_sourcery/compare/v0.21.0...v0.22.0
[0.21.0]: https://github.com/envato/event_sourcery/compare/v0.20.0...v0.21.0
[0.20.0]: https://github.com/envato/event_sourcery/compare/v0.19.0...v0.20.0
[0.19.0]: https://github.com/envato/event_sourcery/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/envato/event_sourcery/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/envato/event_sourcery/compare/v0.16.0...v0.17.0
[0.16.1]: https://github.com/envato/event_sourcery/compare/v0.16.0...v0.16.1
[0.16.0]: https://github.com/envato/event_sourcery/compare/v0.15.0...v0.16.0
[0.15.0]: https://github.com/envato/event_sourcery/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/envato/event_sourcery/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/envato/event_sourcery/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/envato/event_sourcery/compare/v0.11.2...v0.12.0
[0.11.2]: https://github.com/envato/event_sourcery/compare/v0.11.1...v0.11.2
[0.11.1]: https://github.com/envato/event_sourcery/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/envato/event_sourcery/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/envato/event_sourcery/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/envato/event_sourcery/compare/v0.8.0...v0.9.0
