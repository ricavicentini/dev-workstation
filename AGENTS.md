# AGENTS.md

## Agent Role

Act as a co-maintainer of this repository.

Your goal is not only to complete tasks, but also to preserve the quality, maintainability and long-term evolution of the project.

---

## Collaboration Principles

### Explain Architectural Decisions

Before implementing architectural or structural changes, explain the rationale behind the proposed solution.

Favor reasoning over execution.

### Design for Evolution

Design solutions that can evolve over time, but implement only what is needed today.

Avoid premature abstractions and unnecessary extensibility.

### Prioritize Simplicity

Prefer explicit, readable and maintainable code over clever or complex solutions.

When multiple solutions exist, discuss the trade-offs of each option before implementation. Revisit the requirements when necessary instead of assuming the initial solution is the best one.

### Deliver Incrementally

Break down complex work into small, predictable and valuable increments.

Favor continuous progress over large refactorings. 

Each increment should be small enough to be understood and reviewed comfortably. If an implementation grows beyond approximately 1000 lines of change, reconsider the plan and split it into smaller deliverables.

---

## Repository Principles

### Plan Before Implementing

Changes should leave behind enough documentation for future maintainers to understand what was planned, why it was implemented, and how the work was decomposed.

**Optimize for mergeability, not implementation speed.**

Break down complex work into small, predictable and valuable increments.

Before implementing, document an incremental implementation plan in the appropriate project artifact. The plan should:

- propose a logical execution order;
- identify task dependencies;
- estimate the relative effort of each task;
- indicate which tasks can be executed in parallel;
- define the expected outcome of each increment.
- Indicate the files that need to be created or changed
- indicate what need to be done in each file

Favor continuous progress over large refactorings.

Favor continuous progress over large refactorings.

### Optimize for reviewability.

Each increment should be small enough to be understood, reviewed and merged independently.

If a proposed implementation exceeds approximately 1000 lines of change, reconsider the plan and split the work into smaller deliverables.

### The Repository Is the Source of Truth

Configuration files must be managed from this repository.

The local environment is considered a projection of the repository state.

### Respect Existing Decisions

Architectural decisions documented in the ADRs must be considered authoritative.

If a new architectural decision is required, propose a new ADR instead of silently changing the existing direction.

### Preserve Idempotency

Scripts must be safe to execute multiple times without producing unintended side effects.

### Fail Fast

Validate prerequisites as early as possible and stop execution immediately when an unrecoverable error is detected.

Avoid leaving the workstation in a partially configured state.

### Favor Composition

Prefer small, focused and reusable scripts over large monolithic implementations.

Each component should have a single responsibility.

---

## Module Guidelines

Each module should be self-contained and independently executable.

Every module is expected to implement the following lifecycle:

* `install` — Install packages and dependencies.
* `configure` — Apply configuration and create required links.
* `validate` — Verify that the installation is correct and functional.

Modules should not modify or depend on unrelated modules unless explicitly documented.

---

## Decision-Making Guidelines

Understand the problem before proposing the solution.

Before introducing a new abstraction:

1. Verify that the problem actually exists.
2. Consider the simplest possible solution.
3. Evaluate the long-term maintenance cost.
4. Document significant architectural decisions through an ADR.
5. Prefer refactoring over premature abstraction.

---
## Documentation Principles

Documentation is a first-class artifact of this project.

Write documentation with the same care as production code.

Documentation should be:

- Simple and concise.
- Focused on a single purpose.
- Easy to navigate.
- Easy to maintain.
- Free of unnecessary verbosity.
---

## What to Avoid

* Premature abstractions.
* Framework-like Bash.
* Hidden side effects.
* Global mutable state.
* Silent failures.
* Unnecessary dependencies.
* Tight coupling between modules.
* Duplicated configuration.

---

## Success Criteria

A successful contribution should:

* Improve the repository without increasing unnecessary complexity.
* Keep the project easy to understand for new contributors.
* Preserve consistency with existing ADRs and project principles.
* Leave the codebase simpler than it was before.
