# ADR-0002 — Use a Command-Based Module Lifecycle

**Status:** Accepted

## Context

The workstation is composed of technologies that must be installed,
configured and validated independently. A consistent module interface is
needed before the bootstrap can orchestrate those technologies without knowing
their implementation details.

Configuration may modify several files. Stopping after only some changes would
leave the workstation in a partially configured state, contrary to the
project's fail-fast and idempotency principles.

## Decision

Each module shall provide a single executable entrypoint with this interface:

```text
module.sh <install|configure|validate|all>
```

The actions have the following responsibilities:

- `install` installs the module's packages and dependencies;
- `configure` applies managed configuration and validates it before success;
- `validate` checks the installed and configured state without changing it;
- `all` runs install, configure and validate in that order.

An absent or unsupported action shall fail without changing the environment.
Every action shall return zero on success and a non-zero status with a clear
diagnostic on failure.

Configuration shall be transactional within the current process. Until the
managed state is validated, the module records every changed destination. On
failure or receipt of `INT` or `TERM`, it restores those destinations in
reverse order. Destinations that did not exist are removed; destinations moved
to backups are restored.

Rollback is best effort because filesystem recovery can also fail. In that
case, the module shall return a failure, identify the destination that could
not be restored and preserve its backup for manual recovery. This contract
does not provide a public rollback command for earlier successful executions.

## Consequences

### Modules remain independently executable

Developers can run or troubleshoot one lifecycle phase without invoking the
bootstrap.

### The bootstrap has a small integration surface

The orchestrator only needs to select a module and invoke a known action.

### Configuration code must track changes

Modules that modify the workstation carry the additional responsibility of
restoring changes made by a failed execution.

### Validation is part of the transaction

`configure` validates its result before committing. The standalone `validate`
action remains available for diagnostics and future doctor-style commands.

## Alternatives Considered

### Separate executable for each lifecycle phase

Rejected because it multiplies entrypoints and makes orchestration and shared
transaction state harder to follow.

### Source module functions into the bootstrap

Rejected because sourced functions introduce shared shell state and tighter
coupling between modules and the orchestrator.

### Public rollback command

Deferred because undoing a previous successful execution requires persistent
transaction history and retention policies that are unnecessary for the first
module.
