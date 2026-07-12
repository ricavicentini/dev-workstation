# Dev Workstation

A reproducible development environment for WSL built using the principles of **Development Environment as Code (DEaC)**.

Rather than treating a workstation as a collection of installation scripts, this project manages it as a maintainable software system: version-controlled, modular, reproducible and designed to evolve over time.

---

# Vision

Development environments naturally drift over time.

Shell configuration, editor settings, language runtimes and development tools are often installed and configured manually, making it difficult to:

* reproduce the same environment on another machine;
* understand why a configuration exists;
* review changes over time;
* recover from failures;
* share a consistent development environment.

This project aims to eliminate that drift by treating the workstation itself as code.

---

# Goals

* Reproducible workstation setup.
* Development Environment as Code.
* Version-controlled configuration.
* Modular architecture.
* Idempotent execution.
* Incremental evolution.
* Minimal cognitive load.
* Excellent developer experience.

---

# Non-Goals

This project is **not** intended to:

* become a generic package manager;
* replace operating system package managers;
* introduce unnecessary abstractions;
* become a Bash framework.

---

# Repository Structure

```text
.
├── AGENTS.md
├── README.md
├── bootstrap.sh
├── core/
│   ├── homebrew.sh
│   ├── module.sh
│   ├── profile.sh
│   └── symlink.sh
├── dotfiles/
│   ├── git/
│   └── zsh/
├── modules/
│   ├── git/
│   └── zsh/
├── profiles/
│   ├── macos.conf
│   └── ubuntu.conf
├── docs/
│   ├── adr/
│   └── plans/
└── scripts/
```

Git and Zsh are organized as independent technology modules. Their public
entrypoints delegate lifecycle orchestration to `core/module.sh`, while phase
scripts retain technology-specific behavior. Bootstrap uses an explicit
profile to prepare Homebrew before configuring the current modules:

```bash
bash bootstrap.sh ubuntu
# or
bash bootstrap.sh macos
```

The Homebrew installer is interactive when Homebrew is absent. Profiles are
version-controlled data files; they do not detect the operating system or
execute arbitrary commands.

Run the isolated test suite with:

```bash
bash tests/run.sh
```

---

# Roadmap

The roadmap tracks project outcomes. Detailed sequencing, dependencies and
validation remain in the versioned [implementation plans](docs/plans/).

## Foundation completed

* [x] Manage configuration assets from the repository through symbolic links.
* [x] Define the `install`, `configure`, `validate` and `all` module lifecycle.
* [x] Implement transactional symlink management with validation and rollback.
* [x] Organize Zsh configuration as the first technology-owned module.
* [x] Centralize lifecycle dispatch shared by technology modules.
* [x] Organize Git configuration as a technology-owned module and remove the
  temporary dotfiles module.
* [x] Bootstrap and validate the currently supported Git and Zsh assets.
* [x] Add isolated tests for core operations, modules and bootstrap integration.
* [x] Prepare Homebrew through explicit Ubuntu and macOS profiles.

## Next increments

1. [x] Implement Zsh installation, functional configuration and validation
   without changing the default shell.
2. [ ] Implement Git installation, functional configuration and validation.
3. [ ] Migrate module package installation to Homebrew.
4. [ ] Add ordered module selection through profiles.

## Planned capabilities

* [ ] Configure Oh My Posh.
* [ ] Install Nerd Fonts.
* [ ] Install GitHub CLI.
* [ ] Install SDKMAN!
* [ ] Install Java, Kotlin and Gradle.
* [ ] Configure VS Code.
* [ ] Install common development utilities.

## Architecture evolution

* [ ] Add module discovery when the number of modules justifies a loader.
* [ ] Extract shared logging when repeated output behavior justifies it.
* [ ] Add a `doctor` command for complete workstation diagnostics.

---

# License

MIT
