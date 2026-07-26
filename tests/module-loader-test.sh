#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_LOADER="$ROOT_DIR/core/module-loader.sh"
TEST_ROOT="$(mktemp -d)"
TEST_COUNT=0

cleanup() { rm -rf -- "$TEST_ROOT"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { TEST_COUNT=$((TEST_COUNT + 1)); printf 'ok %d - %s\n' "$TEST_COUNT" "$1"; }

make_module() {
  local module_name="$1"
  local body="$2"
  local module_dir="$TEST_ROOT/modules/$module_name"

  mkdir -p "$module_dir"
  printf '%s\n' '#!/usr/bin/env bash' 'set -uo pipefail' "$body" > "$module_dir/module.sh"
  chmod +x "$module_dir/module.sh"
}

test_loader_requires_safe_modules_and_existing_entrypoints() {
  mkdir -p "$TEST_ROOT/modules"

  if bash "$MODULE_LOADER" "$TEST_ROOT/modules" 'Git'; then
    fail 'invalid module name unexpectedly succeeded'
  fi

  if bash "$MODULE_LOADER" "$TEST_ROOT/modules" 'git'; then
    fail 'missing module entrypoint unexpectedly succeeded'
  fi

  pass 'loader rejects unsafe names and missing entrypoints before execution'
}

test_loader_preflights_all_modules_before_running() {
  local log_file="$TEST_ROOT/preflight.log"
  mkdir -p "$TEST_ROOT/modules"
  make_module 'git' "printf 'git:%s\\n' \"\$1\" >> \"$log_file\""
  mkdir -p "$TEST_ROOT/modules/zsh"

  if bash "$MODULE_LOADER" "$TEST_ROOT/modules" git zsh >/dev/null 2>&1; then
    fail 'loader unexpectedly succeeded with a missing second entrypoint'
  fi

  [[ ! -e "$log_file" ]] || fail 'loader executed a module before preflighting the full list'
  pass 'loader preflights the complete module list before running any module'
}

test_loader_runs_all_in_order_and_preserves_environment() {
  local log_file="$TEST_ROOT/order.log"
  mkdir -p "$TEST_ROOT/modules"
  make_module 'git' "printf 'git:%s:%s\\n' \"\$1\" \"\${DEV_WORKSTATION_PACKAGE_PROVIDER:-}\" >> \"$log_file\""
  make_module 'zsh' "printf 'zsh:%s:%s\\n' \"\$1\" \"\${DEV_WORKSTATION_PACKAGE_PROVIDER:-}\" >> \"$log_file\""

  DEV_WORKSTATION_PACKAGE_PROVIDER=brew \
    bash "$MODULE_LOADER" "$TEST_ROOT/modules" git zsh >/dev/null || fail 'loader failed for valid modules'
  [[ "$(<"$log_file")" == $'git:all:brew\nzsh:all:brew' ]] || fail 'loader did not preserve order, action or environment'
  pass 'loader runs all modules in order with the all lifecycle'
}

test_loader_stops_at_first_failure_and_returns_status() {
  local log_file="$TEST_ROOT/failure.log"
  local status
  mkdir -p "$TEST_ROOT/modules"
  make_module 'git' "printf 'git:%s\\n' \"\$1\" >> \"$log_file\"; exit 17"
  make_module 'zsh' "printf 'zsh:%s\\n' \"\$1\" >> \"$log_file\""

  if bash "$MODULE_LOADER" "$TEST_ROOT/modules" git zsh >/dev/null 2>&1; then
    fail 'loader succeeded after a module failure'
  else
    status=$?
  fi

  [[ "$status" -eq 17 ]] || fail 'loader did not return the first failing status'
  [[ "$(<"$log_file")" == 'git:all' ]] || fail 'loader did not stop after the first failure'
  pass 'loader returns the first failing status and skips later modules'
}

printf '1..4\n'
test_loader_requires_safe_modules_and_existing_entrypoints
test_loader_preflights_all_modules_before_running
test_loader_runs_all_in_order_and_preserves_environment
test_loader_stops_at_first_failure_and_returns_status
