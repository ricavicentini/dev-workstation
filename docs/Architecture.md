# Architecture

```text
                     profiles/*.conf
                              │
                              ▼
                         bootstrap.sh
                              │
                              ▼
                    core/profile.sh
                              │
                              ▼
                   core/homebrew.sh
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
        modules/git/module.sh     modules/zsh/module.sh
                │                           │
                └─────────────┬─────────────┘
                              ▼
                        core/module.sh
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
        Git phase scripts             Zsh phase scripts
                │                           │
                └─────────────┬─────────────┘
                              ▼
                     core/symlink.sh
                              │
                              ▼
                          dotfiles/
```

## Responsibilities

| Component     | Responsibility                                                                              |
| ------------- | ------------------------------------------------------------------------------------------- |
| **bootstrap** | Entry point responsible for orchestrating the setup.                                        |
| **core**      | Shared lifecycle orchestration and transactional symlink infrastructure.                     |
| **profiles**  | Explicit workstation preparation strategies consumed by the bootstrap.                       |
| **modules**   | Installation, configuration and validation of a single technology.                          |
| **dotfiles**  | Version-controlled assets owned by their corresponding technology modules.                  |

Git and Zsh are independently executable technology modules, as defined by
[ADR-0003](adr/0003-technology-owned-modules.md). Their entrypoints identify the
module directory and delegate lifecycle dispatch to `core/module.sh`. The
runner does not discover modules or contain technology-specific behavior.

Profiles are selected explicitly by the bootstrap and describe the preparation
strategy for Homebrew. They are parsed as data and do not execute shell code.
The bootstrap still lists Git and Zsh explicitly; profile-driven module loading
is deferred until every listed module can run `all`.

---

# Module Lifecycle

Every module follows the same lifecycle:

1. **install** — Install packages and dependencies.
2. **configure** — Configure the environment and managed files.
3. **validate** — Verify that the module is correctly installed and functional.

Modules expose the lifecycle through a single entrypoint:

```text
module.sh <install|configure|validate|all>
```

A technology module keeps a small public entrypoint and implements lifecycle
behavior in internal phase scripts:

```text
modules/zsh/
├── module.sh       # public wrapper around core/module.sh
├── install.sh      # internal
├── configure.sh    # internal
└── validate.sh     # internal
```

The internal lifecycle runner validates the required phase scripts before
execution. For `all`, it verifies every phase before running them in
`install`, `configure`, `validate` order and stops at the first failure. This
shared dispatch is distinct from module discovery, which remains deferred.

Configuration remains transactional until validation succeeds. If a module
fails or is interrupted while configuring the workstation, it restores the
destinations changed by that execution in reverse order. See
[ADR-0002](adr/0002-module-lifecycle-contract.md) for the complete contract.

Transactions are scoped to the current module. A later module failure does not
undo a module that has already completed and validated successfully.

Modules should always be:

* independently executable;
* idempotent;
* self-contained;
* focused on a single responsibility.

Installation capability is incremental by module. The Zsh module currently
installs the package through the host's Debian/Ubuntu package manager and
validates the executable plus `.zshrc` syntax. Git remains configuration-only
until its own installation increment is implemented. No module changes the
user's default shell automatically.
