# Plan 0002 — Extract the Zsh Module

**Status:** Completed

## Goal

Make Zsh the first module owned by a technology while keeping Git configuration
working through the temporary dotfiles module. Extract the existing symlink
transaction into core infrastructure shared by both modules.

## Increments

| Increment | Work | Effort | Dependencies | Parallel work | Expected outcome |
| --- | --- | --- | --- | --- | --- |
| 1 | Record the plan and architectural decision | Small | None | None | Ownership and the migration boundary are explicit |
| 2 | Extract transactional symlink operations | Medium | Increment 1 | Core tests can be prepared in parallel | Backup, validation and rollback have one implementation |
| 3 | Create the Zsh module and narrow the temporary dotfiles module | Small | Increment 2 | Module tests can be prepared in parallel | Zsh owns `.zshrc`; the temporary module owns only Git files |
| 4 | Integrate, document and validate | Small | Increment 3 | Documentation and tests can proceed in parallel | Bootstrap preserves current configuration behavior through the new boundaries |

## Interfaces

```text
core/symlink.sh <apply|validate> <source> <target> [...]
modules/zsh/module.sh <install|configure|validate|all>
modules/dotfiles/module.sh <install|configure|validate|all>
```

The Zsh phase scripts are internal implementation details. Installation is
deliberately deferred: `install` and therefore `all` fail before changing the
environment. Bootstrap invokes only `configure` and `validate` in this
increment.

## Manual validation

Run every command from the repository root. All changes use temporary home
directories and must never target the real home directory.

1. Prepare an isolated home:

   ```bash
   REPO_ROOT="$PWD"
   TEST_HOME="$(mktemp -d)"
   ```

2. Configure and validate Zsh:

   ```bash
   HOME="$TEST_HOME" bash modules/zsh/module.sh configure
   HOME="$TEST_HOME" bash modules/zsh/module.sh validate
   readlink "$TEST_HOME/.zshrc"
   ```

   The link must point to `$REPO_ROOT/dotfiles/zsh/.zshrc`.

3. Run configuration again and verify idempotency:

   ```bash
   HOME="$TEST_HOME" bash modules/zsh/module.sh configure
   find "$TEST_HOME" -name '.zshrc.backup.*'
   ```

   No backup should be printed.

4. Replace the link with existing configuration and configure again:

   ```bash
   rm "$TEST_HOME/.zshrc"
   printf 'previous configuration\n' > "$TEST_HOME/.zshrc"
   HOME="$TEST_HOME" bash modules/zsh/module.sh configure
   find "$TEST_HOME" -name '.zshrc.backup.*'
   ```

   `.zshrc` must be a managed link and one backup must contain the previous
   content.

5. Verify read-only validation failure:

   ```bash
   rm "$TEST_HOME/.zshrc"
   ln -s /tmp/invalid-zshrc "$TEST_HOME/.zshrc"
   HOME="$TEST_HOME" bash modules/zsh/module.sh validate
   ```

   Validation must return a non-zero status and report the unexpected link.

6. Verify deferred installation with a fresh home:

   ```bash
   INSTALL_HOME="$(mktemp -d)"
   HOME="$INSTALL_HOME" bash modules/zsh/module.sh install
   HOME="$INSTALL_HOME" bash modules/zsh/module.sh all
   find "$INSTALL_HOME" -mindepth 1
   ```

   Both lifecycle commands must fail and `find` must print nothing.

7. Validate the complete bootstrap with another fresh home:

   ```bash
   BOOTSTRAP_HOME="$(mktemp -d)"
   HOME="$BOOTSTRAP_HOME" bash bootstrap.sh
   HOME="$BOOTSTRAP_HOME" bash modules/dotfiles/module.sh validate
   HOME="$BOOTSTRAP_HOME" bash modules/zsh/module.sh validate
   ```

   `.gitconfig`, `.gitignore_global` and `.zshrc` must all be valid links.

8. Remove the temporary homes:

   ```bash
   rm -rf "$TEST_HOME" "$INSTALL_HOME" "$BOOTSTRAP_HOME"
   ```

## Next steps

1. Create a technology-owned Git module and remove the temporary dotfiles
   module.
2. Implement Zsh installation and functional validation.
3. Implement Git installation and functional validation.
4. Add a module loader when the number of modules justifies discovery.
5. Add logging and doctor capabilities when their requirements are concrete.

## Acceptance criteria

- Zsh exclusively owns `.zshrc`.
- The temporary dotfiles module owns only the two Git files.
- Both modules reuse the transactional symlink core.
- Bootstrap configures all three links without installing packages.
- Automated and manual isolated validation pass.

## Validation result

- Seven transactional core scenarios passed.
- Five module and bootstrap integration scenarios passed.
- Bash syntax validation and `git diff --check` passed.
- The complete manual procedure passed with temporary home directories.
