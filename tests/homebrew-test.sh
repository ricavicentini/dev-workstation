#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOMEBREW_SCRIPT="$ROOT_DIR/core/homebrew.sh"
FIXTURE_BIN="$ROOT_DIR/tests/fixtures/bin"
FIXTURE_INSTALLER="$ROOT_DIR/tests/fixtures/homebrew-installer.sh"
TEST_ROOT="$(mktemp -d)"
TEST_COUNT=0

cleanup() { rm -rf -- "$TEST_ROOT"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { TEST_COUNT=$((TEST_COUNT + 1)); printf 'ok %d - %s\n' "$TEST_COUNT" "$1"; }

run_ensure() {
  local strategy="$1"
  local runtime="$2"
  local name="$3"

  PATH="$FIXTURE_BIN:$TEST_ROOT/$name/prefix/bin:$PATH" \
    HOMEBREW_TEST_PREFIX="$TEST_ROOT/$name/prefix" \
    HOMEBREW_TEST_CURL_LOG="$TEST_ROOT/$name/curl.log" \
    HOMEBREW_TEST_INSTALL_LOG="$TEST_ROOT/$name/install.log" \
    HOMEBREW_TEST_INSTALLER="$FIXTURE_INSTALLER" \
    HOMEBREW_TEST_APT_LOG="$TEST_ROOT/$name/apt.log" \
    DEV_WORKSTATION_BREW_PATH="$TEST_ROOT/$name/prefix/bin/brew" \
    bash "$HOMEBREW_SCRIPT" ensure "$strategy" "$runtime"
}

test_ubuntu_installs_prerequisites_and_homebrew() {
  local brew_path
  mkdir -p "$TEST_ROOT/ubuntu"
  brew_path="$(run_ensure apt-get system ubuntu)" || fail 'Ubuntu Homebrew provisioning failed'

  [[ "$brew_path" == "$TEST_ROOT/ubuntu/prefix/bin/brew" ]] || fail 'unexpected Brew path'
  [[ "$(<"$TEST_ROOT/ubuntu/curl.log")" == 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' ]] || fail 'unexpected installer URL'
  [[ "$(<"$TEST_ROOT/ubuntu/install.log")" == installer-ran ]] || fail 'installer did not run'
  pass 'Ubuntu strategy prepares Homebrew with the official installer'
}

test_macos_skips_apt_and_installs_bash() {
  local brew_path
  mkdir -p "$TEST_ROOT/macos"
  brew_path="$(run_ensure installer brew macos)" || fail 'macOS Homebrew provisioning failed'

  [[ -x "$TEST_ROOT/macos/prefix/bin/bash" ]] || fail 'Brew Bash was not installed'
  [[ ! -e "$TEST_ROOT/macos/apt.log" ]] || fail 'macOS strategy used apt-get'
  [[ "$brew_path" == "$TEST_ROOT/macos/prefix/bin/brew" ]] || fail 'unexpected Brew path'
  pass 'macOS strategy delegates prerequisites and installs Brew Bash'
}

printf '1..2\n'
test_ubuntu_installs_prerequisites_and_homebrew
test_macos_skips_apt_and_installs_bash
