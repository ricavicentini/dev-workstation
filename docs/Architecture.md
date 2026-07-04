# Architecture

```text
                         bootstrap.sh
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
 modules/dotfiles (temporary)          modules/zsh
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
| **core**      | Shared infrastructure with concrete reuse across modules, currently symlink management.      |
| **modules**   | Installation, configuration and validation of a single technology.                          |
| **dotfiles**  | Version-controlled assets owned by their corresponding technology modules.                  |

The dotfiles module is a temporary migration boundary that owns only the Git
assets. Zsh is the first technology-owned module. The temporary module will be
removed when Git receives its own module, as defined by
[ADR-0003](adr/0003-technology-owned-modules.md).

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

A technology module may split lifecycle behavior into internal scripts:

```text
modules/zsh/
├── module.sh       # public entrypoint
├── install.sh      # internal
├── configure.sh    # internal
└── validate.sh     # internal
```

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
