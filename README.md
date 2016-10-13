# EventSourcery

A framework for building event sourced, CQRS applications.

## Goals

The goal of Event Sourcery is to make it easier to build event sourced, CQRS applications.

The hope is that by using EventSourcery you can focus on modeling your domain with aggregates, commands, and events; and not worry about stitching together application plumbing.

## Core Concepts

Refer to [core concepts](./docs/core-concepts.md) to learn about the core pieces of EventSourcery.

## Getting Started Guide

**TODO**

## Applications that use EventSourcery

- [Identity](https://github.com/envato/identity) (note that this was the original ES/CQRS implementation that ES was extracted from).
- [Payables](https://github.com/envato/payables).
- [Calendar Example App](https://github.com/envato/calendar-es-example).

## Development

### Dependencies

- Postgresql
- Ruby

### Running the Test Suite

Run the `setup` script, inside the project directory to install the gem dependencies and create the test database (if it is not already created).
```bash
./bin/setup
```

Then you can run the test suite with rspec:
```bash
rspec
```

