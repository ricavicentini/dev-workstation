# Guiding Principles

## Design for Evolution

Design systems that can evolve over time, but implement only what is required today.

Avoid premature abstractions.

## Simplicity First

Prefer explicit, understandable solutions over clever abstractions.

Optimize for maintainability.

## Composition over Coupling

Build small, focused components instead of monolithic scripts.

## Idempotency

Every operation must be safe to execute multiple times without unintended side effects.

## Fail Fast

Validate prerequisites as early as possible.

Abort execution before producing inconsistent environments.

## Single Source of Truth

The repository is the source of truth for the workstation configuration.

The local environment is considered a projection of the repository state.

## Documentation as Code

Documentation is a first-class artifact of this project.

Documentation should be:

* simple;
* concise;
* focused on a single responsibility;
* easy to navigate;
* easy to maintain;
* free of unnecessary duplication.

Every significant change should leave enough documentation for future maintainers to understand:

* why it exists;
* how it was implemented;
* which trade-offs were accepted.

When documentation becomes difficult to read, split it into smaller documents instead of making it longer.