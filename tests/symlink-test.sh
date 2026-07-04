#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT_DIR/core/symlink.sh"
FIXTURE_BIN="$ROOT_DIR/tests/fixtures/bin"
REAL_LN="$(command -v ln)"
REAL_MV="$(command -v mv)"
REAL_RM="$(command -v rm)"
TEST_ROOT="$(mktemp -d)"
TEST_COUNT=0

SOURCE_ZSH="$ROOT_DIR/dotfiles/zsh/.zshrc"
SOURCE_GIT="$ROOT_DIR/dotfiles/git/.gitconfig"
SOURCE_IGNORE="$ROOT_DIR/dotfiles/git/.gitignore_global"

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

apply_all() {
  local home="$1"

  bash "$CORE" apply \
    "$SOURCE_ZSH" "$home/.zshrc" \
    "$SOURCE_GIT" "$home/.gitconfig" \
    "$SOURCE_IGNORE" "$home/.gitignore_global"
}

validate_all() {
  local home="$1"

  bash "$CORE" validate \
    "$SOURCE_ZSH" "$home/.zshrc" \
    "$SOURCE_GIT" "$home/.gitconfig" \
    "$SOURCE_IGNORE" "$home/.gitignore_global"
}

backup_files() {
  local target="$1"

  compgen -G "${target}.backup.*" || true
}

run_with_controlled_commands() {
  local home="$1"
  local mode="$2"
  local output="$3"
  local rm_failure="${4:-0}"

    PATH="$FIXTURE_BIN:$PATH" \
    SYMLINK_TEST_LN_MODE="$mode" \
    SYMLINK_TEST_LN_COUNT_FILE="${output}.ln-count" \
    SYMLINK_TEST_REAL_LN="$REAL_LN" \
    SYMLINK_TEST_REAL_MV="$REAL_MV" \
    SYMLINK_TEST_REAL_RM="$REAL_RM" \
    SYMLINK_TEST_RM_FAIL="$rm_failure" \
    SYMLINK_TEST_WRONG_SOURCE="$SOURCE_ZSH" \
    bash "$CORE" apply \
      "$SOURCE_ZSH" "$home/.zshrc" \
      "$SOURCE_GIT" "$home/.gitconfig" \
      "$SOURCE_IGNORE" "$home/.gitignore_global" >"$output" 2>&1
}

test_apply_validate_and_idempotency() {
  local home
  local backups
  home="$(new_home idempotency)"

  apply_all "$home" >/dev/null || fail 'initial apply failed'
  validate_all "$home" >/dev/null || fail 'validation failed'
  apply_all "$home" >/dev/null || fail 'idempotent apply failed'
  [[ -z "$(backup_files "$home/.zshrc")" ]] || fail 'idempotent apply created a backup'

  "$REAL_RM" -f "$home/.zshrc"
  printf 'previous zsh configuration\n' > "$home/.zshrc"
  apply_all "$home" >/dev/null || fail 'apply over existing file failed'
  backups="$(backup_files "$home/.zshrc")"
  [[ "$(printf '%s\n' "$backups" | sed '/^$/d' | wc -l)" -eq 1 ]] || fail 'existing file did not create one backup'
  [[ "$(<"$backups")" == 'previous zsh configuration' ]] || fail 'backup content was not preserved'
  pass 'apply is validated, idempotent and preserves existing files'
}

test_preflight_and_validation_failures() {
  local home
  home="$(new_home preflight)"
  printf 'original\n' > "$home/.zshrc"

  if bash "$CORE" apply "$SOURCE_ZSH" >/dev/null 2>&1; then
    fail 'incomplete source-target pair unexpectedly succeeded'
  fi

  if bash "$CORE" apply "$SOURCE_ZSH" '' >/dev/null 2>&1; then
    fail 'empty target unexpectedly succeeded'
  fi

  if bash "$CORE" apply "$TEST_ROOT/missing-source" "$home/.zshrc" >/dev/null 2>&1; then
    fail 'missing source unexpectedly succeeded'
  fi
  [[ "$(<"$home/.zshrc")" == 'original' ]] || fail 'missing-source preflight changed the target'

  if bash "$CORE" apply "$SOURCE_ZSH" "$home/.zshrc" "$SOURCE_GIT" "$home/.zshrc" >/dev/null 2>&1; then
    fail 'duplicate target unexpectedly succeeded'
  fi
  [[ "$(<"$home/.zshrc")" == 'original' ]] || fail 'duplicate-target preflight changed the target'

  "$REAL_RM" -f "$home/.zshrc"
  "$REAL_LN" -s /tmp/unexpected "$home/.zshrc"
  if bash "$CORE" validate "$SOURCE_ZSH" "$home/.zshrc" >/dev/null 2>&1; then
    fail 'validation accepted an unexpected link'
  fi
  pass 'preflight and validation failures are read-only'
}

test_operational_failure_rolls_back() {
  local home
  local output="$TEST_ROOT/failure-output"
  home="$(new_home operation-failure)"
  printf 'original zsh\n' > "$home/.zshrc"
  printf 'original git\n' > "$home/.gitconfig"

  if run_with_controlled_commands "$home" fail-second "$output"; then
    fail 'controlled link failure unexpectedly succeeded'
  fi
  [[ ! -L "$home/.zshrc" && "$(<"$home/.zshrc")" == 'original zsh' ]] || fail '.zshrc was not restored'
  [[ ! -L "$home/.gitconfig" && "$(<"$home/.gitconfig")" == 'original git' ]] || fail '.gitconfig was not restored'
  [[ ! -e "$home/.gitignore_global" && ! -L "$home/.gitignore_global" ]] || fail 'absent target was not restored'
  pass 'operational failure rolls back all changed targets'
}

test_link_interruption_rolls_back() {
  local home
  local output="$TEST_ROOT/link-signal-output"
  home="$(new_home link-interruption)"
  printf 'original zsh\n' > "$home/.zshrc"
  printf 'original git\n' > "$home/.gitconfig"

  if run_with_controlled_commands "$home" term-second "$output"; then
    fail 'interrupted apply unexpectedly succeeded'
  fi
  [[ ! -L "$home/.zshrc" && "$(<"$home/.zshrc")" == 'original zsh' ]] || fail '.zshrc was not restored after interruption'
  [[ ! -L "$home/.gitconfig" && "$(<"$home/.gitconfig")" == 'original git' ]] || fail '.gitconfig was not restored after interruption'
  grep -q 'received TERM' "$output" || fail 'TERM interruption was not reported'
  pass 'link interruption triggers rollback'
}

test_backup_interruption_rolls_back() {
  local home
  local output="$TEST_ROOT/backup-signal-output"
  home="$(new_home backup-interruption)"
  printf 'original zsh\n' > "$home/.zshrc"

  if PATH="$FIXTURE_BIN:$PATH" \
    SYMLINK_TEST_MV_MODE='term-after-first' \
    SYMLINK_TEST_MV_COUNT_FILE="$TEST_ROOT/mv-count" \
    SYMLINK_TEST_REAL_MV="$REAL_MV" \
    SYMLINK_TEST_REAL_RM="$REAL_RM" \
    SYMLINK_TEST_RM_FAIL=0 \
    bash "$CORE" apply "$SOURCE_ZSH" "$home/.zshrc" >"$output" 2>&1; then
    fail 'backup interruption unexpectedly succeeded'
  fi
  [[ ! -L "$home/.zshrc" && "$(<"$home/.zshrc")" == 'original zsh' ]] || fail '.zshrc was not restored after backup interruption'
  [[ -z "$(backup_files "$home/.zshrc")" ]] || fail 'restored backup was left behind'
  pass 'interruption immediately after backup triggers rollback'
}

test_rollback_failure_preserves_backup() {
  local home
  local output="$TEST_ROOT/rollback-failure-output"
  local backup
  home="$(new_home rollback-failure)"
  printf 'original zsh\n' > "$home/.zshrc"
  printf 'original git\n' > "$home/.gitconfig"

  if run_with_controlled_commands "$home" fail-second "$output" 1; then
    fail 'apply with rollback failure unexpectedly succeeded'
  fi
  backup="$(backup_files "$home/.zshrc")"
  [[ -n "$backup" && "$(<"$backup")" == 'original zsh' ]] || fail 'recoverable backup was not preserved'
  grep -q 'backup preserved at:' "$output" || fail 'preserved backup was not reported'
  pass 'rollback failure reports and preserves the recoverable backup'
}

test_validation_failure_rolls_back() {
  local home
  local output="$TEST_ROOT/validation-rollback-output"
  home="$(new_home validation-rollback)"
  printf 'original zsh\n' > "$home/.zshrc"
  printf 'original git\n' > "$home/.gitconfig"

  if run_with_controlled_commands "$home" wrong-third "$output"; then
    fail 'invalid final link unexpectedly succeeded'
  fi
  [[ ! -L "$home/.zshrc" && "$(<"$home/.zshrc")" == 'original zsh' ]] || fail '.zshrc was not restored after validation failure'
  [[ ! -L "$home/.gitconfig" && "$(<"$home/.gitconfig")" == 'original git' ]] || fail '.gitconfig was not restored after validation failure'
  [[ ! -e "$home/.gitignore_global" && ! -L "$home/.gitignore_global" ]] || fail 'invalid link was not removed'
  pass 'validation failure rolls back the complete transaction'
}

printf '1..7\n'
test_apply_validate_and_idempotency
test_preflight_and_validation_failures
test_operational_failure_rolls_back
test_link_interruption_rolls_back
test_backup_interruption_rolls_back
test_rollback_failure_preserves_backup
test_validation_failure_rolls_back
