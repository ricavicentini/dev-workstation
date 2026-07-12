# Architecture Decision Records (ADR)

This directory contains the Architecture Decision Records (ADRs) for the project.

An ADR captures an important architectural decision together with its context and consequences.

## Status

An ADR may have one of the following states:

* Proposed
* Accepted
* Superseded
* Deprecated

## Naming

ADRs are numbered sequentially.

Example:

```text
0001-use-dotfiles.md
0002-modular-architecture.md
0003-idempotent-modules.md
```

## Records

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-use-dotfiles.md) | Use dotfiles as the source of truth | Accepted |
| [0002](0002-module-lifecycle-contract.md) | Use a command-based module lifecycle | Accepted |
| [0003](0003-technology-owned-modules.md) | Organize modules by technology | Accepted |
| [0004](0004-explicit-profiles.md) | Use explicit workstation profiles | Accepted |

## Guidelines

* ADRs are immutable.
* Do not rewrite history.
* If a decision changes, create a new ADR referencing the previous one.
* Keep ADRs concise and focused on a single decision.

The goal is to preserve the reasoning behind the architecture, not just the final outcome.
