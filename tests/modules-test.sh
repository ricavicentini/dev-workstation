#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_MODULE="$ROOT_DIR/modules/git/module.sh"
ZSH_MODULE="$ROOT_DIR/modules/zsh/module.sh"
BOOTSTRAP="$ROOT_DIR/bootstrap.sh"
FIXTURE_BIN="$ROOT_DIR/tests/fixtures/bin"
REAL_LN="$(command -v ln)"
REAL_MV="$(command -v mv)"
REAL_RM="$(command -v rm)"
TEST_ROOT="$(mktemp -d)"
TEST_COUNT=0

cleanup() {
  "$REAL_RM" -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf 'ok %d - %s\n' "$TEST_COUNT" "$1"
}

new_home() {
  local name="$1"
  local home="$TEST_ROOT/$name"

  mkdir -p "$home"
  printf '%s\n' "$home"
}

assert_link() {
  local target="$1"
  local source="$2"

  [[ -L "$target" ]] || fail "$target is not a symbolic link"
  [[ "$(readlink "$target")" == "$source" ]] || fail "$target points to an unexpected source"
}

backup_files() {
  local target="$1"

  compgen -G "${target}.backup.*" || true
}

test_git_module_owns_only_git() {
  local home
  home="$(new_home git-ownership)"

  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'Git module configuration failed'
  HOME="$home" bash "$GIT_MODULE" validate >/dev/null || fail 'Git module validation failed'
  assert_link "$home/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
  assert_link "$home/.gitignore_global" "$ROOT_DIR/dotfiles/git/.gitignore_global"
  [[ ! -e "$home/.zshrc" && ! -L "$home/.zshrc" ]] || fail 'Git module changed .zshrc'
  pass 'Git module owns only Git assets'
}

test_zsh_module_owns_only_zsh() {
  local home
  home="$(new_home zsh-ownership)"

  HOME="$home" bash "$ZSH_MODULE" configure >/dev/null || fail 'Zsh configuration failed'
  HOME="$home" bash "$ZSH_MODULE" validate >/dev/null || fail 'Zsh validation failed'
  assert_link "$home/.zshrc" "$ROOT_DIR/dotfiles/zsh/.zshrc"
  [[ ! -e "$home/.gitconfig" && ! -L "$home/.gitconfig" ]] || fail 'Zsh module changed .gitconfig'
  [[ ! -e "$home/.gitignore_global" && ! -L "$home/.gitignore_global" ]] || fail 'Zsh module changed .gitignore_global'
  pass 'Zsh module owns only .zshrc'
}

test_zsh_deferred_installation_has_no_side_effects() {
  local home
  home="$(new_home deferred-install)"

  if HOME="$home" bash "$ZSH_MODULE" install >/dev/null 2>&1; then
    fail 'deferred install unexpectedly succeeded'
  fi
  if HOME="$home" bash "$ZSH_MODULE" all >/dev/null 2>&1; then
    fail 'deferred all action unexpectedly succeeded'
  fi
  [[ -z "$(find "$home" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail 'deferred installation changed HOME'
  pass 'deferred install and all actions fail without side effects'
}

test_git_deferred_installation_has_no_side_effects() {
  local home
  home="$(new_home git-deferred-install)"

  if HOME="$home" bash "$GIT_MODULE" install >/dev/null 2>&1; then
    fail 'Git install unexpectedly succeeded'
  fi
  if HOME="$home" bash "$GIT_MODULE" all >/dev/null 2>&1; then
    fail 'Git all action unexpectedly succeeded'
  fi
  [[ -z "$(find "$home" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail 'deferred Git installation changed HOME'
  pass 'Git install and all fail without side effects'
}

test_git_configuration_is_idempotent_and_preserves_existing_files() {
  local home
  local backups
  local backup
  local previous_found=0
  local replacement_found=0
  home="$(new_home git-idempotency)"

  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'initial Git configuration failed'
  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'repeated Git configuration failed'
  [[ -z "$(backup_files "$home/.gitconfig")" ]] || fail 'idempotent Git configuration created a .gitconfig backup'
  [[ -z "$(backup_files "$home/.gitignore_global")" ]] || fail 'idempotent Git configuration created a .gitignore_global backup'

  "$REAL_RM" -f -- "$home/.gitconfig"
  printf 'previous git configuration\n' > "$home/.gitconfig"
  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'Git configuration over an existing file failed'

  backups="$(backup_files "$home/.gitconfig")"
  [[ "$(printf '%s\n' "$backups" | sed '/^$/d' | wc -l)" -eq 1 ]] || fail 'existing .gitconfig did not create exactly one backup'
  [[ "$(<"$backups")" == 'previous git configuration' ]] || fail '.gitconfig backup content was not preserved'
  assert_link "$home/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
  assert_link "$home/.gitignore_global" "$ROOT_DIR/dotfiles/git/.gitignore_global"

  "$REAL_RM" -f -- "$home/.gitconfig"
  printf 'replacement git configuration\n' > "$home/.gitconfig"
  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'second Git replacement failed'

  backups="$(backup_files "$home/.gitconfig")"
  [[ "$(printf '%s\n' "$backups" | sed '/^$/d' | wc -l)" -eq 2 ]] || fail 'Git replacements did not create unique backups'
  while IFS= read -r backup; do
    case "$(<"$backup")" in
      'previous git configuration')
        previous_found=1
        ;;
      'replacement git configuration')
        replacement_found=1
        ;;
    esac
  done <<< "$backups"
  ((previous_found == 1 && replacement_found == 1)) || fail 'unique Git backups did not preserve both versions'
  pass 'Git configuration is idempotent and creates unique recoverable backups'
}

test_git_failure_rolls_back_both_targets() {
  local home
  local output="$TEST_ROOT/git-rollback-output"
  home="$(new_home git-rollback)"
  printf 'original git configuration\n' > "$home/.gitconfig"

  if HOME="$home" \
    PATH="$FIXTURE_BIN:$PATH" \
    SYMLINK_TEST_LN_MODE='fail-second' \
    SYMLINK_TEST_LN_COUNT_FILE="$TEST_ROOT/git-rollback-count" \
    SYMLINK_TEST_REAL_LN="$REAL_LN" \
    SYMLINK_TEST_REAL_MV="$REAL_MV" \
    SYMLINK_TEST_REAL_RM="$REAL_RM" \
    SYMLINK_TEST_RM_FAIL=0 \
    bash "$GIT_MODULE" configure >"$output" 2>&1; then
    fail 'controlled Git failure unexpectedly succeeded'
  fi

  [[ ! -L "$home/.gitconfig" && "$(<"$home/.gitconfig")" == 'original git configuration' ]] || fail '.gitconfig was not restored'
  [[ ! -e "$home/.gitignore_global" && ! -L "$home/.gitignore_global" ]] || fail 'absent .gitignore_global was not restored'
  [[ -z "$(backup_files "$home/.gitconfig")" ]] || fail 'restored Git backup was left behind'
  pass 'Git configuration failure rolls back both targets'
}

test_bootstrap_configures_all_assets() {
  local home
  local output="$TEST_ROOT/bootstrap-output"
  home="$(new_home bootstrap)"

  HOME="$home" bash "$BOOTSTRAP" >"$output" || fail 'bootstrap failed'
  assert_link "$home/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
  assert_link "$home/.gitignore_global" "$ROOT_DIR/dotfiles/git/.gitignore_global"
  assert_link "$home/.zshrc" "$ROOT_DIR/dotfiles/zsh/.zshrc"
  grep -q '^Configuring Git\.\.\.$' "$output" || fail 'bootstrap did not identify Git configuration'
  grep -q '^Git validated\.$' "$output" || fail 'bootstrap did not identify Git validation'
  grep -q '^Configuring Zsh\.\.\.$' "$output" || fail 'bootstrap did not identify Zsh configuration'
  grep -q '^Zsh validated\.$' "$output" || fail 'bootstrap did not identify Zsh validation'
  if grep -q '^Symbolic links ' "$output"; then
    fail 'bootstrap exposed generic core success messages'
  fi
  pass 'bootstrap configures and validates Git before Zsh'
}

test_zsh_failure_keeps_validated_git() {
  local home
  local output="$TEST_ROOT/zsh-failure-output"
  home="$(new_home module-boundary)"

  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'Git setup failed'
  if HOME="$home" \
    PATH="$FIXTURE_BIN:$PATH" \
    SYMLINK_TEST_LN_MODE='fail-first' \
    SYMLINK_TEST_LN_COUNT_FILE="$TEST_ROOT/zsh-failure-count" \
    SYMLINK_TEST_REAL_LN="$REAL_LN" \
    SYMLINK_TEST_REAL_MV="$REAL_MV" \
    SYMLINK_TEST_REAL_RM="$REAL_RM" \
    SYMLINK_TEST_RM_FAIL=0 \
    bash "$ZSH_MODULE" configure >"$output" 2>&1; then
    fail 'controlled Zsh failure unexpectedly succeeded'
  fi

  assert_link "$home/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
  assert_link "$home/.gitignore_global" "$ROOT_DIR/dotfiles/git/.gitignore_global"
  [[ ! -e "$home/.zshrc" && ! -L "$home/.zshrc" ]] || fail 'failed Zsh module left .zshrc behind'
  pass 'Zsh failure does not undo the validated Git module'
}

printf '1..8\n'
test_git_module_owns_only_git
test_zsh_module_owns_only_zsh
test_zsh_deferred_installation_has_no_side_effects
test_git_deferred_installation_has_no_side_effects
test_git_configuration_is_idempotent_and_preserves_existing_files
test_git_failure_rolls_back_both_targets
test_bootstrap_configures_all_assets
test_zsh_failure_keeps_validated_git
