# ADR-0004 — Use Explicit Workstation Profiles

**Status:** Accepted

## Context

Ubuntu and macOS need different preparation before Homebrew can install shared
development tools. Automatic OS detection would hide a material workstation
choice, while YAML would introduce a parser dependency into the bootstrap path.

## Decision

The bootstrap requires an explicit profile:

```text
bootstrap.sh <profile-name>
```

Profiles are version-controlled `key=value` files. They select Homebrew
prerequisites, the package provider and the required Bash runtime. They are
data only: no commands are sourced or executed from profile files.

Homebrew is installed interactively from the current official installer when
absent. Ubuntu prerequisites use `apt-get`; the macOS profile delegates Command
Line Tools preparation to the Homebrew installer. Module selection remains
explicit until Git and Zsh both implement `all` successfully.

## Consequences

- The user chooses a profile; the project does not detect the host OS.
- Homebrew provisioning is idempotent but external package changes are not
  rolled back.
- The current installer URL is intentionally not pinned; reproducibility of
  that external installer is deferred.
- A later increment may add ordered module entries to profiles and a loader.

## Alternatives Considered

### YAML profiles

Deferred because YAML needs a parser before dependencies are installed.

### Execute commands from profiles

Rejected because it hides side effects and creates an unbounded shell recipe
format.

### Detect the operating system automatically

Rejected because explicit workstation intent is easier to review and diagnose.
