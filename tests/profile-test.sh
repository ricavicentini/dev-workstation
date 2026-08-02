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
  profile="$(write_profile valid 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'bash_runtime=system' 'module=git' 'module=zsh' 'module=github-cli')"

  bash "$PROFILE_SCRIPT" validate "$profile" || fail 'valid profile was rejected'
  [[ "$(bash "$PROFILE_SCRIPT" get "$profile" package_provider)" == brew ]] || fail 'profile value was not returned'
  [[ "$(bash "$PROFILE_SCRIPT" modules "$profile")" == $'git\nzsh\ngithub-cli' ]] || fail 'profile modules were not returned in declaration order'
  pass 'valid profile is accepted and preserves module order'
}

test_invalid_profiles() {
  local duplicate duplicate_module unknown missing required_module invalid_module
  duplicate="$(write_profile duplicate 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'package_provider=brew' 'bash_runtime=system' 'module=git')"
  duplicate_module="$(write_profile duplicate-module 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'bash_runtime=system' 'module=git' 'module=git')"
  unknown="$(write_profile unknown 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'bash_runtime=system' 'module=git' 'unexpected=value')"
  missing="$(write_profile missing 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'module=git')"
  required_module="$(write_profile missing-module 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'bash_runtime=system')"
  invalid_module="$(write_profile invalid-module 'homebrew_prerequisites=apt-get' 'package_provider=brew' 'bash_runtime=system' 'module=Git')"

  bash "$PROFILE_SCRIPT" validate "$duplicate" >/dev/null 2>&1 && fail 'duplicate profile key was accepted'
  bash "$PROFILE_SCRIPT" validate "$duplicate_module" >/dev/null 2>&1 && fail 'duplicate profile module was accepted'
  bash "$PROFILE_SCRIPT" validate "$unknown" >/dev/null 2>&1 && fail 'unknown profile key was accepted'
  bash "$PROFILE_SCRIPT" validate "$missing" >/dev/null 2>&1 && fail 'missing profile key was accepted'
  bash "$PROFILE_SCRIPT" validate "$required_module" >/dev/null 2>&1 && fail 'profile without modules was accepted'
  bash "$PROFILE_SCRIPT" validate "$invalid_module" >/dev/null 2>&1 && fail 'invalid module name was accepted'
  pass 'invalid profiles fail before use'
}

test_real_profiles_declare_git_zsh_github_cli_then_java() {
  [[ "$(bash "$PROFILE_SCRIPT" modules "$ROOT_DIR/profiles/ubuntu.conf")" == $'git\nzsh\ngithub-cli\njava' ]] || fail 'ubuntu profile modules differ from git then zsh then github-cli then java'
  [[ "$(bash "$PROFILE_SCRIPT" modules "$ROOT_DIR/profiles/macos.conf")" == $'git\nzsh\ngithub-cli\njava' ]] || fail 'macos profile modules differ from git then zsh then github-cli then java'
  pass 'real profiles declare git, zsh, github-cli and java in order'
}

printf '1..3\n'
test_valid_profile
test_invalid_profiles
test_real_profiles_declare_git_zsh_github_cli_then_java
