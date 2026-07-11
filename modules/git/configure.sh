#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
  printf 'Error: HOME must reference an existing directory.\n' >&2
  exit 1
fi

printf 'Configuring Git...\n'
if ! bash "$ROOT_DIR/core/symlink.sh" apply \
  "$ROOT_DIR/dotfiles/git/.gitconfig" "$HOME/.gitconfig" \
  "$ROOT_DIR/dotfiles/git/.gitignore_global" "$HOME/.gitignore_global"; then
  exit 1
fi
printf 'Git configured.\n'
