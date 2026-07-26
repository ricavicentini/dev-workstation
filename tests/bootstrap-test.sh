#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$ROOT_DIR/bootstrap.sh"
FIXTURE_BIN="$ROOT_DIR/tests/fixtures/bin"
FIXTURE_INSTALLER="$ROOT_DIR/tests/fixtures/homebrew-installer.sh"
TEST_ROOT="$(mktemp -d)"
TEST_COUNT=0
REAL_BASH="$(command -v bash)"

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

test_macos_profile_reexecs_with_brew_bash_before_modules() {
  local home="$TEST_ROOT/macos-home"
  local output="$TEST_ROOT/macos-output"
  local homebrew_root="$TEST_ROOT/macos-homebrew"
  local bash_log="$TEST_ROOT/macos-bash.log"

  mkdir -p "$home" "$homebrew_root/bin"
  cp "$FIXTURE_BIN/curl" "$FIXTURE_BIN/sudo" "$homebrew_root/bin"
  chmod +x "$homebrew_root/bin/curl" "$homebrew_root/bin/sudo"

  HOME="$home" \
    PATH="$homebrew_root/bin:$homebrew_root/prefix/bin:$PATH" \
    HOMEBREW_TEST_PREFIX="$homebrew_root/prefix" \
    HOMEBREW_TEST_CURL_LOG="$homebrew_root/curl.log" \
    HOMEBREW_TEST_INSTALL_LOG="$homebrew_root/install.log" \
    HOMEBREW_TEST_INSTALLER="$FIXTURE_INSTALLER" \
    HOMEBREW_TEST_BREW_LOG="$homebrew_root/brew.log" \
    HOMEBREW_TEST_REAL_BASH="$REAL_BASH" \
    HOMEBREW_TEST_BASH_LOG="$bash_log" \
    DEV_WORKSTATION_BREW_PATH="$homebrew_root/prefix/bin/brew" \
    /bin/bash "$BOOTSTRAP" macos >"$output" || fail 'macOS bootstrap failed'

  [[ -x "$homebrew_root/prefix/bin/bash" ]] || fail 'macOS bootstrap did not provision Brew Bash'
  if [[ "$(/bin/bash -c 'printf %s "${BASH_VERSINFO[0]}"')" -lt 4 ]]; then
    [[ -f "$bash_log" ]] || fail 'macOS bootstrap did not re-exec through Brew Bash'
    grep -Fxq "$ROOT_DIR/bootstrap.sh" "$bash_log" || fail 'macOS bootstrap did not re-exec through Brew Bash'
  else
    grep -Fxq "$ROOT_DIR/bootstrap.sh" "$bash_log" && fail 'bootstrap re-execed unexpectedly on modern /bin/bash'
  fi

  grep -q '^Installing git with Homebrew\.\.\.$' "$output" || fail 'macOS bootstrap did not start modules after Bash preparation'
  grep -q '^Installing zsh with Homebrew\.\.\.$' "$output" || fail 'macOS bootstrap did not complete ordered module execution'
  pass 'macOS bootstrap prepares Brew Bash before modules when required'
}

printf '1..4\n'
test_invalid_usage_does_not_install
test_missing_profile_does_not_install
test_bootstrap_uses_profile_loader_instead_of_hardcoded_modules
test_macos_profile_reexecs_with_brew_bash_before_modules
