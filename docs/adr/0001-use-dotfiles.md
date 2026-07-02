# ADR-0001 — Use Dotfiles as the Source of Truth

**Status:** Accepted

## Context

The project aims to provide a reproducible development environment that can be recreated on any machine.

Managing configuration files directly inside the user's home directory makes it difficult to version changes, review configuration history, and reproduce the environment consistently.

## Decision

All supported configuration files shall be stored inside this repository and managed as version-controlled assets.

The user's home directory will contain symbolic links pointing to the files maintained by this repository.

Example:

```text
~/.zshrc
        │
        ▼
dotfiles/zsh/.zshrc
```

The bootstrap process is responsible for creating and maintaining these symbolic links while preserving any existing user configuration.

## Benefits

* Single source of truth for workstation configuration.
* Full version history through Git.
* Reproducible development environments.
* Fast onboarding on new machines.
* Simplified backup and recovery.
* Easier review and evolution of configuration changes.

## Trade-offs

### Home directory becomes dependent on the repository

Configuration files are no longer stored directly in the user's home directory. Instead, they are represented by symbolic links.

### Bootstrap becomes responsible for link management

The bootstrap process must safely create, update and maintain symbolic links.

### Direct editing may introduce configuration drift

Editing files directly in the home directory bypasses version control and may cause the repository to no longer reflect the actual environment.

## Mitigations

* The bootstrap process must create backups before replacing existing files.
* All operations must be idempotent, allowing the bootstrap to run multiple times safely.
* The bootstrap must validate that every symbolic link points to the expected target.
* Configuration changes should always be made inside this repository.
* Future validation commands (for example, `doctor`) should detect broken or missing symbolic links.

## Alternatives Considered

### Store configuration directly in the home directory

Rejected because configuration history would not be version-controlled and migrating to a new machine would require manual steps.

### Copy files instead of using symbolic links

Rejected because copied files diverge over time, creating configuration drift between the repository and the local machine.

## Future Considerations

If the number of managed components grows significantly, the bootstrap process may evolve to support selective installation of modules (for example, Git, Kotlin or VS Code independently).

This ADR intentionally does not define how module selection will work. That decision should be documented in a future ADR when the need arises.

