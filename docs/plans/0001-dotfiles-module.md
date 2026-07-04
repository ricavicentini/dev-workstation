# Plan 0001 — Dotfiles Module Foundation

**Status:** Completed

## Goal

Turn the existing dotfile linker into the first complete module, with an
explicit lifecycle, validation, idempotent execution and automatic rollback.

## Increments

| Increment | Work | Effort | Dependencies | Parallel work | Expected outcome |
| --- | --- | --- | --- | --- | --- |
| 1 | Record this implementation plan | Small | None | None | The intended sequence and trade-offs are preserved before implementation |
| 2 | Define the module contract in ADR-0002 | Small | Increment 1 | None | Future modules have a stable lifecycle interface |
| 3 | Implement and integrate the dotfiles module | Medium | Increment 2 | Tests may be prepared after the contract is accepted | Dotfiles can be installed, configured and validated as one independent module |
| 4 | Add isolated tests and align documentation | Medium | Increment 3 | Tests and documentation can proceed in parallel | Idempotency, validation and recovery behavior are verified and documented |

## Transaction boundary

Configuration is transactional until all managed links have been validated.
The module records each destination changed by the current execution. If an
operation fails or the process receives `INT` or `TERM`, it restores those
destinations in reverse order.

Rollback only covers the current execution. It removes links created for
previously absent destinations and restores destinations moved to backups. If
restoration itself fails, the module reports the affected destination and
leaves its backup available for manual recovery.

Backups created by a successful configuration are retained, as required by
ADR-0001. A public command for undoing earlier successful executions is outside
this increment.

## Acceptance criteria

- The module exposes `install`, `configure`, `validate` and `all` actions.
- Repeated execution produces the same links without additional backups.
- Existing divergent destinations are preserved in unique backups.
- A failed or interrupted configuration restores the initial state.
- Validation rejects missing, broken or unexpected links.
- The bootstrap completes only after the module validates successfully.

## Validation result

The isolated Bash test suite covers bootstrap integration, idempotency, unique
backups, invalid links, operational failures, interruptions at link and backup
boundaries, rollback recovery errors, validation failures and preflight
failures.
