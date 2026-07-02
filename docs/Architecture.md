# Architecture

```text
                 bootstrap.sh
                      │
                      ▼
                    core
                      │
                      ▼
               module loader
                      │
                      ▼
                   modules
                      │
                      ▼
                  dotfiles
```

## Responsibilities

| Component     | Responsibility                                                                              |
| ------------- | ------------------------------------------------------------------------------------------- |
| **bootstrap** | Entry point responsible for orchestrating the setup.                                        |
| **core**      | Shared infrastructure such as logging, validation, symlink management and module discovery. |
| **modules**   | Installation, configuration and validation of a single technology.                          |
| **dotfiles**  | Version-controlled configuration files managed by the repository.                           |

---

# Module Lifecycle

Every module follows the same lifecycle:

1. **install** — Install packages and dependencies.
2. **configure** — Configure the environment and managed files.
3. **validate** — Verify that the module is correctly installed and functional.

Modules should always be:

* independently executable;
* idempotent;
* self-contained;
* focused on a single responsibility.