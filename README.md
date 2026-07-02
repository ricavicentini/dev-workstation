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
├── dotfiles/
├── modules/
├── docs/
│   └── adr/
└── scripts/
```

---

# Roadmap

* [ ] Configure Zsh
* [ ] Configure Oh My Posh
* [ ] Install Nerd Fonts
* [ ] Configure Git
* [ ] Install GitHub CLI
* [ ] Install SDKMAN!
* [ ] Install Java
* [ ] Install Kotlin
* [ ] Install Gradle
* [ ] Configure VS Code
* [ ] Install development utilities
* [ ] Implement the bootstrap orchestrator
* [ ] Implement the module loader
* [ ] Implement module validation
* [ ] Add a `doctor` command

---

# License

MIT
