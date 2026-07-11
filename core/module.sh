#!/usr/bin/env bash

set -uo pipefail

usage() {
  printf 'Usage: module.sh <install|configure|validate|all>\n' >&2
}

log_error() {
  printf 'Error: %s\n' "$*" >&2
}

preflight() {
  local module_dir="$1"
  shift
  local phase
  local script

  if [[ ! -d "$module_dir" ]]; then
    log_error "module directory does not exist: $module_dir"
    return 1
  fi

  for phase in "$@"; do
    script="$module_dir/$phase.sh"

    if [[ ! -f "$script" || ! -r "$script" ]]; then
      log_error "module phase is not readable: $script"
      return 1
    fi
  done
}

run_phases() {
  local module_dir="$1"
  shift
  local phase
  local status

  for phase in "$@"; do
    bash "$module_dir/$phase.sh"
    status=$?

    if ((status != 0)); then
      return "$status"
    fi
  done
}

main() {
  local module_dir
  local action
  local -a phases

  if (($# != 2)); then
    usage
    return 2
  fi

  module_dir="$1"
  action="$2"

  case "$action" in
    install|configure|validate)
      phases=("$action")
      ;;
    all)
      phases=(install configure validate)
      ;;
    *)
      usage
      return 2
      ;;
  esac

  preflight "$module_dir" "${phases[@]}" || return 1
  run_phases "$module_dir" "${phases[@]}"
}

main "$@"
