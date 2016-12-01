# EventSourcery

A framework for building event sourced, CQRS applications.

## Goals

The goal of EventSourcery is to make it easier to build event sourced, CQRS applications.

The hope is that by using EventSourcery you can focus on modeling your domain with aggregates, commands, and events; and not worry about stitching together application plumbing.

## Core Concepts

Refer to [core concepts](./docs/core-concepts.md) to learn about the core pieces of EventSourcery.

## Getting Started Guide

**TODO**

## Applications that use EventSourcery

- [Identity](https://github.com/envato/identity) (note that this was the ES/CQRS implementation that ES was initially extracted from).
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

# Resources

Not sure what Event Sourcing (ES), Command Query Responsibility Segregation (CQRS), or even Domain-Driven Design (DDD) are? Here are a few links to get you started:

* [CQRS and Event Sourcing Talk](https://www.youtube.com/watch?v=JHGkaShoyNs) - by Greg Young at Code on the Beach 2014
* [DDD/CQRS Google Group](https://groups.google.com/forum/#!forum/dddcqrs) - from people new to the concepts to old hands
* [DDD Weekly Newsletter](https://buildplease.com/pages/dddweekly/) - a weekly digest of what's happening in the community
* [Domain-Driven Design](https://www.amazon.com/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215) - the definitive guide
* [Greg Young's Blog](https://goodenoughsoftware.net) - a (the?) lead proponent of all things Event Sourcing
