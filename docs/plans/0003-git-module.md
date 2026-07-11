# Plan 0003 — Extract the Git Module and Centralize the Lifecycle

**Status:** Completed

**Issue:** [#2 — Extract Git into a technology-owned module](https://github.com/ricavicentini/dev-workstation/issues/2)

## Goal

Complete the migration defined by ADR-0003 by making Git responsible for
`.gitconfig` and `.gitignore_global`, removing the temporary dotfiles module
and centralizing lifecycle dispatch shared by Git and Zsh.

Each technology keeps its public entrypoint:

```text
modules/<technology>/module.sh <install|configure|validate|all>
```

The entrypoint identifies its module directory and invokes the internal runner:

```text
core/module.sh <module-directory> <install|configure|validate|all>
```

Package installation and functional Git diagnostics remain separate future
work.

## Architectural rationale

Git creates the second concrete use of the lifecycle dispatcher, satisfying
ADR-0003's requirement that shared operations have demonstrated reuse. The
common runner owns argument validation and phase ordering, while small public
wrappers preserve independently executable technology modules.

The runner does not discover modules, map technology names or know about
managed assets. It is therefore not the deferred module loader. It invokes
phase scripts with `bash` instead of sourcing them, avoiding shared shell state.

A single root entrypoint was rejected because it would change the public API
defined by ADR-0002 and make modules dependent on an external selector. Keeping
the dispatcher in every module was rejected because its identical behavior
would be repeated for every future technology.

ADR-0002 and ADR-0003 already support this structure, so no new ADR is needed.
Previous ADRs and completed plans remain unchanged as historical records.

## Increments

| Increment | Work | Effort | Dependencies | Parallel work | Expected outcome |
| --- | --- | --- | --- | --- | --- |
| 1 | Record the shared lifecycle decision and affected files | Small | ADR-0002, ADR-0003 and issue #2 | None | Implementation is decision-complete before structural changes |
| 2 | Extract and test the lifecycle runner, then migrate Zsh | Medium | Increment 1 | Runner tests can be prepared in parallel | Zsh preserves its public behavior through the shared lifecycle |
| 3 | Create and test the Git module | Small | Increment 2 | Integration tests can be prepared in parallel | Git independently manages its two assets through the runner and symlink core |
| 4 | Switch bootstrap and remove the temporary module | Small | Increment 3 | Documentation can proceed in parallel | No active caller depends on `modules/dotfiles/` |
| 5 | Update current documentation and complete validation | Small | Increment 4 | Automated and manual validation can run in parallel | Executable behavior, architecture and roadmap agree |

The work remains one reviewable contribution below approximately 1,000 changed
lines. Each increment should form a coherent commit boundary.

## Files

### Create

| File | Change |
| --- | --- |
| `core/module.sh` | Validate the internal runner arguments and required phase scripts, dispatch individual phases and run `all` in lifecycle order |
| `tests/module-lifecycle-test.sh` | Verify dispatch, ordering, short-circuiting, invalid input and preflight behavior |
| `modules/git/module.sh` | Preserve the public module interface through a minimal wrapper around the runner |
| `modules/git/install.sh` | Fail explicitly without side effects while package installation is deferred |
| `modules/git/configure.sh` | Apply both Git assets in one symlink-core transaction |
| `modules/git/validate.sh` | Validate both Git links without changing the environment |

### Change

| File | Change |
| --- | --- |
| `modules/zsh/module.sh` | Replace its duplicated dispatcher with the same minimal runner wrapper |
| `tests/run.sh` | Run lifecycle tests before symlink and module integration tests |
| `tests/modules-test.sh` | Replace temporary-module coverage with Git ownership, deferred installation, idempotency, backup, rollback and bootstrap integration scenarios |
| `tests/fixtures/bin/ln`, `mv` and `rm` | Preserve executable file modes so controlled-command tests also work from a native Linux filesystem |
| `bootstrap.sh` | Configure and validate Git through its technology-owned entrypoint before Zsh |
| `README.md` | Show the runner and Git module, explain the current bootstrap behavior and update the roadmap |
| `docs/Architecture.md` | Describe the shared lifecycle runner, phase scripts and technology-owned modules |
| `docs/plans/0003-git-module.md` | Record this design and, after validation, the completed status and results |

### Remove

| File | Change |
| --- | --- |
| `modules/dotfiles/module.sh` | Remove only after all active callers and tests use the Git module |

`core/symlink.sh`, managed assets, ADRs, completed plans and production-script
permissions remain unchanged.

## Lifecycle behavior

`core/module.sh` has an internal interface and shall:

- require exactly a module directory and one action;
- accept only `install`, `configure`, `validate` and `all`;
- return status 2 for invalid usage or actions without running a phase;
- return status 1 with a clear diagnostic for a missing module directory or
  required phase script;
- preflight every required script before the first phase; `all` must therefore
  verify all three scripts before running `install`;
- invoke phase scripts with `bash` and no additional arguments;
- run `all` as `install`, `configure`, then `validate`;
- stop at the first phase failure and propagate its status.

Public module wrappers calculate their module and repository paths, then replace
themselves with the runner process. Phase scripts retain all technology-specific
messages and behavior.

Git `configure` manages both links in one transaction. Git `install`, and thus
`all`, fails before changing the environment. Bootstrap continues to invoke
`configure` and `validate` directly while installation is deferred.

## Automated tests

Lifecycle tests cover:

- dispatch of each individual phase;
- lifecycle order for `all`;
- stopping after a failed phase and preserving its status;
- missing, extra and unsupported arguments without phase execution;
- missing phase scripts failing preflight before `all` starts.

Module tests cover:

- Git owns only `.gitconfig` and `.gitignore_global`;
- Zsh continues to own only `.zshrc`;
- Git `install` and `all` fail without changing an isolated `HOME`;
- repeated Git configuration is idempotent;
- an existing divergent Git target receives one unique backup;
- a controlled failure on the second Git link restores the initial state;
- bootstrap configures and validates Git before Zsh;
- a Zsh failure does not undo the validated Git module.

Run from the repository root:

```bash
bash tests/run.sh
find . -type f -name '*.sh' -print0 | xargs -0 bash -n
git diff --check
rg 'modules/dotfiles' bootstrap.sh modules tests README.md docs/Architecture.md
```

The final command must return no matches. Historical ADRs and completed plans
are intentionally outside this active-reference check.

## Manual validation

Use temporary home directories and run all commands from the repository root.

1. Prepare isolated homes:

   ```bash
   REPO_ROOT="$PWD"
   TEST_HOME="$(mktemp -d)"
   INSTALL_HOME="$(mktemp -d)"
   BOOTSTRAP_HOME="$(mktemp -d)"
   ```

2. Configure and validate Git:

   ```bash
   HOME="$TEST_HOME" bash modules/git/module.sh configure
   HOME="$TEST_HOME" bash modules/git/module.sh validate
   readlink "$TEST_HOME/.gitconfig"
   readlink "$TEST_HOME/.gitignore_global"
   ```

   Both links must point into `$REPO_ROOT/dotfiles/git/`, and `.zshrc` must not
   exist.

3. Repeat configuration and confirm that no backup is created:

   ```bash
   HOME="$TEST_HOME" bash modules/git/module.sh configure
   find "$TEST_HOME" -name '*.backup.*'
   ```

4. Replace `.gitconfig` and confirm preservation of its previous content:

   ```bash
   rm "$TEST_HOME/.gitconfig"
   printf 'previous configuration\n' > "$TEST_HOME/.gitconfig"
   HOME="$TEST_HOME" bash modules/git/module.sh configure
   find "$TEST_HOME" -name '.gitconfig.backup.*' -type f -print
   ```

5. Confirm deferred installation has no effects:

   ```bash
   HOME="$INSTALL_HOME" bash modules/git/module.sh install
   HOME="$INSTALL_HOME" bash modules/git/module.sh all
   find "$INSTALL_HOME" -mindepth 1
   ```

   Both lifecycle commands must fail and `find` must print nothing.

6. Validate the complete bootstrap:

   ```bash
   HOME="$BOOTSTRAP_HOME" bash bootstrap.sh
   HOME="$BOOTSTRAP_HOME" bash modules/git/module.sh validate
   HOME="$BOOTSTRAP_HOME" bash modules/zsh/module.sh validate
   ```

   `.gitconfig`, `.gitignore_global` and `.zshrc` must be valid managed links,
   and output must identify Git and Zsh phases.

7. Remove temporary homes:

   ```bash
   rm -rf "$TEST_HOME" "$INSTALL_HOME" "$BOOTSTRAP_HOME"
   ```

Controlled filesystem failures remain automated because fixtures are safer and
more reproducible than manual fault injection.

## Acceptance criteria

- Lifecycle dispatch has one implementation.
- Git and Zsh retain independent public `module.sh` entrypoints.
- Invalid runner usage does not execute module phases.
- `all` preflights every phase and stops at the first execution failure.
- Git exclusively owns its two managed assets.
- Git configuration remains idempotent and transactional.
- Deferred Git installation has no side effects.
- Bootstrap creates and validates all three supported links in Git-to-Zsh order.
- A later Zsh failure preserves a previously validated Git module.
- No active reference to the temporary dotfiles module remains.
- Automated checks and the isolated manual procedure pass.

## Out of scope

- Discovering or selecting modules by technology name.
- Installing Git or changing package-manager state.
- Functional checks against the Git executable.
- Changing Zsh phase behavior.
- Adding shared logging or a doctor command.
- Changing symlink-core behavior unless validation exposes a separate defect.

## Validation result

- Five lifecycle-runner scenarios passed.
- Seven transactional symlink-core scenarios passed.
- Eight module and bootstrap integration scenarios passed.
- Bash syntax validation and `git diff --check` passed.
- Active code and current documentation contain no temporary-module reference.
- The complete manual procedure passed with isolated home directories.
- Native Linux execution exposed non-executable controlled-command fixtures;
  their executable modes were recorded so rollback tests remain portable.
