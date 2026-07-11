#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT_DIR/core/module.sh"
TEST_ROOT="$(mktemp -d)"
TEST_COUNT=0

cleanup() {
  rm -rf -- "$TEST_ROOT"
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

new_module() {
  local name="$1"
  local module_dir="$TEST_ROOT/$name"

  mkdir -p "$module_dir"
  printf '%s\n' "$module_dir"
}

write_phase() {
  local module_dir="$1"
  local phase="$2"
  local status="${3:-0}"

  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "printf '%s\\n' '$phase' >> \"\${MODULE_TEST_LOG:?}\"" \
    "exit $status" > "$module_dir/$phase.sh"
}

create_complete_module() {
  local module_dir="$1"
  local phase

  for phase in install configure validate; do
    write_phase "$module_dir" "$phase"
  done
}

assert_log() {
  local expected="$1"
  local actual=''

  if [[ -f "$MODULE_TEST_LOG" ]]; then
    actual="$(<"$MODULE_TEST_LOG")"
  fi

  [[ "$actual" == "$expected" ]] || fail "unexpected phase log: $actual"
}

test_dispatches_individual_phases() {
  local module_dir
  local phase

  module_dir="$(new_module individual)"
  create_complete_module "$module_dir"

  for phase in install configure validate; do
    MODULE_TEST_LOG="$TEST_ROOT/individual-$phase.log"
    MODULE_TEST_LOG="$MODULE_TEST_LOG" bash "$RUNNER" "$module_dir" "$phase" || fail "$phase did not run"
    assert_log "$phase"
  done

  pass 'individual actions dispatch only their requested phase'
}

test_all_runs_in_order() {
  local module_dir

  module_dir="$(new_module all-order)"
  create_complete_module "$module_dir"
  MODULE_TEST_LOG="$TEST_ROOT/all-order.log"

  MODULE_TEST_LOG="$MODULE_TEST_LOG" bash "$RUNNER" "$module_dir" all || fail 'all failed'
  assert_log $'install\nconfigure\nvalidate'
  pass 'all runs lifecycle phases in order'
}

test_phase_failure_stops_all() {
  local module_dir
  local status

  module_dir="$(new_module phase-failure)"
  write_phase "$module_dir" install
  write_phase "$module_dir" configure 70
  write_phase "$module_dir" validate
  MODULE_TEST_LOG="$TEST_ROOT/phase-failure.log"

  MODULE_TEST_LOG="$MODULE_TEST_LOG" bash "$RUNNER" "$module_dir" all
  status=$?

  [[ "$status" -eq 70 ]] || fail "runner returned $status instead of the phase status"
  assert_log $'install\nconfigure'
pass 'all stops at the first failure and preserves its status'  
}

test_invalid_usage_runs_nothing() {
  local module_dir
  local status

  module_dir="$(new_module invalid-usage)"
  create_complete_module "$module_dir"
  MODULE_TEST_LOG="$TEST_ROOT/invalid-usage.log"

  MODULE_TEST_LOG="$MODULE_TEST_LOG" bash "$RUNNER" "$module_dir" >/dev/null 2>&1
  status=$?
  [[ "$status" -eq 2 ]] || fail 'missing action did not return status 2'

  MODULE_TEST_LOG="$MODULE_TEST_LOG" bash "$RUNNER" "$module_dir" unsupported >/dev/null 2>&1
  status=$?
  [[ "$status" -eq 2 ]] || fail 'unsupported action did not return status 2'

  MODULE_TEST_LOG="$MODULE_TEST_LOG" bash "$RUNNER" "$module_dir" install extra >/dev/null 2>&1
  status=$?
  [[ "$status" -eq 2 ]] || fail 'extra argument did not return status 2'

  assert_log ''
  pass 'invalid usage returns status 2 without running phases'
}

test_all_preflights_every_phase() {
  local module_dir
  local status

  module_dir="$(new_module incomplete)"
  write_phase "$module_dir" install
  write_phase "$module_dir" validate
  MODULE_TEST_LOG="$TEST_ROOT/incomplete.log"

  MODULE_TEST_LOG="$MODULE_TEST_LOG" bash "$RUNNER" "$TEST_ROOT/missing" all >/dev/null 2>&1
  status=$?
  [[ "$status" -eq 1 ]] || fail 'missing module directory did not return status 1'

  if MODULE_TEST_LOG="$MODULE_TEST_LOG" bash "$RUNNER" "$module_dir" all >/dev/null 2>&1; then
    fail 'incomplete module unexpectedly succeeded'
  fi
  assert_log ''
  pass 'all preflights the module and every phase before execution'
}

printf '1..5\n'
test_dispatches_individual_phases
test_all_runs_in_order
test_phase_failure_stops_all
test_invalid_usage_runs_nothing
test_all_preflights_every_phase
