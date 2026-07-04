#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_MODULE="$ROOT_DIR/modules/dotfiles/module.sh"
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

test_temporary_module_owns_only_git() {
  local home
  home="$(new_home git-ownership)"

  HOME="$home" bash "$DOTFILES_MODULE" configure >/dev/null || fail 'temporary module configuration failed'
  HOME="$home" bash "$DOTFILES_MODULE" validate >/dev/null || fail 'temporary module validation failed'
  assert_link "$home/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
  assert_link "$home/.gitignore_global" "$ROOT_DIR/dotfiles/git/.gitignore_global"
  [[ ! -e "$home/.zshrc" && ! -L "$home/.zshrc" ]] || fail 'temporary module changed .zshrc'
  pass 'temporary module owns only Git assets'
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

test_deferred_installation_has_no_side_effects() {
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

  HOME="$home" bash "$DOTFILES_MODULE" configure >/dev/null || fail 'Git setup failed'
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

printf '1..5\n'
test_temporary_module_owns_only_git
test_zsh_module_owns_only_zsh
test_deferred_installation_has_no_side_effects
test_bootstrap_configures_all_assets
test_zsh_failure_keeps_validated_git
