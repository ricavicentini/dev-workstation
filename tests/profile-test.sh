#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_SCRIPT="$ROOT_DIR/core/profile.sh"
TEST_ROOT="$(mktemp -d)"
TEST_COUNT=0

cleanup() { rm -rf -- "$TEST_ROOT"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { TEST_COUNT=$((TEST_COUNT + 1)); printf 'ok %d - %s\n' "$TEST_COUNT" "$1"; }

write_profile() {
  local name="$1"
  shift
  printf '%s\n' "$@" > "$TEST_ROOT/$name.conf"
  printf '%s\n' "$TEST_ROOT/$name.conf"
}

test_valid_profile() {
  local profile
  profile="$(write_profile valid 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'bash_runtime=system')"

  bash "$PROFILE_SCRIPT" validate "$profile" || fail 'valid profile was rejected'
  [[ "$(bash "$PROFILE_SCRIPT" get "$profile" package_provider)" == brew ]] || fail 'profile value was not returned'
  pass 'valid profile is accepted and queried'
}

test_invalid_profiles() {
  local duplicate unknown missing
  duplicate="$(write_profile duplicate 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'package_provider=brew' 'bash_runtime=system')"
  unknown="$(write_profile unknown 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'bash_runtime=system' 'module=zsh')"
  missing="$(write_profile missing 'homebrew_prerequisites=apt-get' 'package_provider=brew')"

  bash "$PROFILE_SCRIPT" validate "$duplicate" >/dev/null 2>&1 && fail 'duplicate profile key was accepted'
  bash "$PROFILE_SCRIPT" validate "$unknown" >/dev/null 2>&1 && fail 'unknown profile key was accepted'
  bash "$PROFILE_SCRIPT" validate "$missing" >/dev/null 2>&1 && fail 'missing profile key was accepted'
  pass 'invalid profiles fail before use'
}

printf '1..2\n'
test_valid_profile
test_invalid_profiles
