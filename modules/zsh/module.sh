#!/usr/bin/env bash

set -uo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  printf 'Usage: %s <install|configure|validate|all>\n' "$0" >&2
}

main() {
  local action="${1:-}"

  if (($# != 1)); then
    usage
    return 2
  fi

  case "$action" in
    install)
      bash "$MODULE_DIR/install.sh"
      ;;
    configure)
      bash "$MODULE_DIR/configure.sh"
      ;;
    validate)
      bash "$MODULE_DIR/validate.sh"
      ;;
    all)
      bash "$MODULE_DIR/install.sh" && \
        bash "$MODULE_DIR/configure.sh" && \
        bash "$MODULE_DIR/validate.sh"
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
