#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$ROOT_DIR/bootstrap.sh"
FIXTURE_BIN="$ROOT_DIR/tests/fixtures/bin"
TEST_ROOT="$(mktemp -d)"
TEST_COUNT=0

cleanup() { rm -rf -- "$TEST_ROOT"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { TEST_COUNT=$((TEST_COUNT + 1)); printf 'ok %d - %s\n' "$TEST_COUNT" "$1"; }

test_invalid_usage_does_not_install() {
  local output="$TEST_ROOT/usage-output"

  if PATH="$FIXTURE_BIN:$PATH" bash "$BOOTSTRAP" >"$output" 2>&1; then
    fail 'bootstrap without a profile unexpectedly succeeded'
  fi
  [[ ! -e "$TEST_ROOT/curl.log" ]] || fail 'invalid bootstrap usage invoked the installer'
  pass 'bootstrap requires a profile before provisioning'
}

test_missing_profile_does_not_install() {
  local output="$TEST_ROOT/missing-output"

  if PATH="$FIXTURE_BIN:$PATH" bash "$BOOTSTRAP" missing >"$output" 2>&1; then
    fail 'missing profile unexpectedly succeeded'
  fi
  [[ ! -e "$TEST_ROOT/curl.log" ]] || fail 'missing profile invoked the installer'
  pass 'bootstrap validates the profile before provisioning'
}

test_bootstrap_uses_profile_loader_instead_of_hardcoded_modules() {
  grep -q 'core/module-loader\.sh' "$BOOTSTRAP" || fail 'bootstrap does not use the module loader'
  grep -Eq 'modules/(git|zsh)/module\.sh' "$BOOTSTRAP" && fail 'bootstrap still references Git or Zsh entrypoints directly'
  pass 'bootstrap delegates module execution to the profile-driven loader'
}

printf '1..3\n'
test_invalid_usage_does_not_install
test_missing_profile_does_not_install
test_bootstrap_uses_profile_loader_instead_of_hardcoded_modules
