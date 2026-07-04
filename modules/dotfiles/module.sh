#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYMLINK_CORE="$ROOT_DIR/core/symlink.sh"

usage() {
  printf 'Usage: %s <install|configure|validate|all>\n' "$0" >&2
}

require_home() {
  if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
    printf 'Error: HOME must reference an existing directory.\n' >&2
    return 1
  fi
}

install_dotfiles() {
  printf 'The temporary Git dotfiles module has no packages to install.\n'
}

configure_dotfiles() {
  require_home || return 1

  printf 'Configuring Git...\n'
  if ! bash "$SYMLINK_CORE" apply \
    "$ROOT_DIR/dotfiles/git/.gitconfig" "$HOME/.gitconfig" \
    "$ROOT_DIR/dotfiles/git/.gitignore_global" "$HOME/.gitignore_global"; then
    return 1
  fi
  printf 'Git configured.\n'
}

validate_dotfiles() {
  require_home || return 1

  printf 'Validating Git...\n'
  if ! bash "$SYMLINK_CORE" validate \
    "$ROOT_DIR/dotfiles/git/.gitconfig" "$HOME/.gitconfig" \
    "$ROOT_DIR/dotfiles/git/.gitignore_global" "$HOME/.gitignore_global"; then
    return 1
  fi
  printf 'Git validated.\n'
}

main() {
  local action="${1:-}"

  if (($# != 1)); then
    usage
    return 2
  fi

  case "$action" in
    install)
      install_dotfiles
      ;;
    configure)
      configure_dotfiles
      ;;
    validate)
      validate_dotfiles
      ;;
    all)
      install_dotfiles && configure_dotfiles && validate_dotfiles
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
