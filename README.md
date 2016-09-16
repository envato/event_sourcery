# EventSourcery

A framework for building event sourced, CQRS applications.

## Core Concepts

Refer to [core concepts](./docs/core-concepts.md) to learn about the core pieces of EventSourcery.

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

