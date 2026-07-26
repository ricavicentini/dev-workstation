#!/usr/bin/env bash

set -uo pipefail

usage() {
  printf 'Usage: module-loader.sh <modules-dir> <module>...\n' >&2
}

log_error() {
  printf 'Error: %s\n' "$*" >&2
}

is_safe_module_name() {
  local module_name="$1"

  [[ "$module_name" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

preflight() {
  local modules_dir="$1"
  shift
  local module_name
  local module_dir
  local entrypoint

  [[ -d "$modules_dir" ]] || {
    log_error "modules directory does not exist: $modules_dir"
    return 1
  }

  for module_name in "$@"; do
    if ! is_safe_module_name "$module_name"; then
      log_error "invalid module name: $module_name"
      return 1
    fi

    module_dir="$modules_dir/$module_name"
    entrypoint="$module_dir/module.sh"
    [[ -d "$module_dir" ]] || {
      log_error "module directory does not exist: $module_dir"
      return 1
    }
    [[ -f "$entrypoint" && -r "$entrypoint" ]] || {
      log_error "module entrypoint is not readable: $entrypoint"
      return 1
    }
  done
}

run_modules() {
  local modules_dir="$1"
  shift
  local module_name
  local status

  for module_name in "$@"; do
    bash "$modules_dir/$module_name/module.sh" all
    status=$?

    if ((status != 0)); then
      return "$status"
    fi
  done
}

main() {
  local modules_dir="${1:-}"

  (($# >= 2)) || {
    usage
    return 2
  }

  preflight "$modules_dir" "${@:2}" || return 1
  run_modules "$modules_dir" "${@:2}"
}

main "$@"
