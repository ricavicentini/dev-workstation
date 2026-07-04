# ADR-0003 — Organize Modules by Technology

**Status:** Accepted

## Context

The first module grouped every managed configuration file under a dotfiles
responsibility. This proved the lifecycle and rollback contract, but dotfiles
describe version-controlled assets rather than an independently installable
workstation capability.

Keeping all configuration in one module would make that module change whenever
Git, Zsh, VS Code or another technology evolves. It would also combine package
installation, configuration and validation for unrelated tools.

## Decision

Modules shall be organized by the technology they manage. A technology module
owns its installation, configuration, validation and corresponding assets.
The `dotfiles/` directory remains the version-controlled asset store and is not
a module in the target architecture.

Each module preserves the public interface established by ADR-0002:

```text
module.sh <install|configure|validate|all>
```

The public entrypoint delegates lifecycle work to internal `install.sh`,
`configure.sh` and `validate.sh` scripts. These phase scripts are implementation
details and are not stable public interfaces.

Reusable workstation operations belong in `core/` only after at least one
concrete use exists. Transactional symbolic-link management is the first such
operation. Logging, module discovery and doctor capabilities are deferred until
their behavior is required.

Transactions are scoped to the module currently running. A failure in a later
module does not undo a previously validated module.

## Incremental Migration

Zsh is the first technology-owned module and exclusively manages `.zshrc`.
During the migration, the existing dotfiles module remains temporarily and
manages only `.gitconfig` and `.gitignore_global`. A following increment will
create the Git module and remove the temporary module.

Package installation is outside this migration increment. Until Zsh
installation is implemented, its `install` and `all` actions fail explicitly
before changing the environment. Bootstrap invokes `configure` and `validate`
directly to preserve its current behavior.

## Consequences

### Ownership follows the reason for change

Changes to Zsh configuration affect the Zsh module without changing unrelated
technology modules.

### The public module contract remains stable

The additional phase scripts improve readability without expanding the public
API rejected by ADR-0002.

### Shared behavior has one implementation

Backup, symlink validation and rollback move to core instead of being copied
into each technology module.

### The repository has a temporary asymmetry

Git remains in the dotfiles module until the next migration increment. This is
accepted to keep each contribution small and independently verifiable.

## Alternatives Considered

### Keep one dotfiles module

Rejected because it couples unrelated technologies to a single growing
module.

### Migrate Git and Zsh together

Rejected for this increment because it makes the architectural change larger
than necessary. Git is explicitly recorded as the next migration.

### Create the complete core upfront

Rejected because loader, logger and doctor abstractions do not yet have
concrete behavior to support.
