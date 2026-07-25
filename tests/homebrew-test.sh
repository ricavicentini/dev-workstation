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

run_homebrew() {
  local name="$1"
  shift

  PATH="$TEST_ROOT/$name/prefix/bin:$PATH" \
    HOMEBREW_TEST_PREFIX="$TEST_ROOT/$name/prefix" \
    HOMEBREW_TEST_BREW_LOG="$TEST_ROOT/$name/brew.log" \
    HOMEBREW_TEST_INSTALL_FAIL="${HOMEBREW_TEST_INSTALL_FAIL:-}" \
    HOMEBREW_TEST_INSTALL_WITHOUT_FORMULA="${HOMEBREW_TEST_INSTALL_WITHOUT_FORMULA:-}" \
    HOMEBREW_TEST_ZSH_SYNTAX_STATUS="${HOMEBREW_TEST_ZSH_SYNTAX_STATUS:-0}" \
    DEV_WORKSTATION_BREW_PATH="$TEST_ROOT/$name/prefix/bin/brew" \
    bash "$HOMEBREW_SCRIPT" "$@"
}

prepare_homebrew() {
  local name="$1"

  mkdir -p "$TEST_ROOT/$name"
  run_ensure installer system "$name" >/dev/null || fail "Homebrew setup failed for $name"
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

test_install_formula_installs_when_missing() {
  prepare_homebrew formula-install

  run_homebrew formula-install install git >/dev/null || fail 'formula installation failed'
  [[ "$(<"$TEST_ROOT/formula-install/brew.log")" == 'brew install git' ]] || fail 'formula installation was not delegated to Brew'
  [[ -f "$TEST_ROOT/formula-install/prefix/formula/git" ]] || fail 'installed formula was not recorded'
  [[ -x "$TEST_ROOT/formula-install/prefix/bin/git" ]] || fail 'installed executable was not created'
  pass 'missing formula is installed and confirmed'
}

test_install_formula_is_idempotent() {
  prepare_homebrew formula-idempotent
  HOMEBREW_TEST_PREFIX="$TEST_ROOT/formula-idempotent/prefix" \
    HOMEBREW_TEST_BREW_LOG="$TEST_ROOT/formula-idempotent/brew.log" \
    "$TEST_ROOT/formula-idempotent/prefix/bin/brew" install git >/dev/null || fail 'fixture formula setup failed'
  rm -f "$TEST_ROOT/formula-idempotent/brew.log"

  run_homebrew formula-idempotent install git >/dev/null || fail 'installed formula was not accepted'
  [[ ! -e "$TEST_ROOT/formula-idempotent/brew.log" ]] || fail 'idempotent formula install invoked Brew'
  pass 'installed formula does not reinstall'
}

test_validate_formula_checks_formula_executable_and_path() {
  prepare_homebrew formula-validate
  HOMEBREW_TEST_PREFIX="$TEST_ROOT/formula-validate/prefix" \
    "$TEST_ROOT/formula-validate/prefix/bin/brew" install git >/dev/null || fail 'fixture formula setup failed'

  run_homebrew formula-validate validate git git >/dev/null || fail 'installed formula did not validate'
  rm -f "$TEST_ROOT/formula-validate/prefix/bin/git"
  if run_homebrew formula-validate validate git git >/dev/null 2>&1; then
    fail 'formula validation succeeded without the Homebrew executable'
  fi
  pass 'formula validation checks formula, executable and PATH'
}

test_install_formula_reports_missing_after_install() {
  prepare_homebrew formula-missing-after-install

  if HOMEBREW_TEST_INSTALL_WITHOUT_FORMULA=git \
    run_homebrew formula-missing-after-install install git >/dev/null 2>&1; then
    fail 'formula install succeeded without final formula confirmation'
  fi
  pass 'formula installation fails when Brew does not confirm the formula'
}

printf '1..6\n'
test_ubuntu_installs_prerequisites_and_homebrew
test_macos_skips_apt_and_installs_bash
test_install_formula_installs_when_missing
test_install_formula_is_idempotent
test_validate_formula_checks_formula_executable_and_path
test_install_formula_reports_missing_after_install
