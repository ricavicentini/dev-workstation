#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
  printf 'Error: HOME must reference an existing directory.\n' >&2
  exit 1
fi

printf 'Validating Git...\n'
if ! bash "$ROOT_DIR/core/homebrew.sh" validate git git; then
  exit 1
fi

if ! git --version >/dev/null; then
  printf 'Error: git executable is not functional.\n' >&2
  exit 1
fi

if ! bash "$ROOT_DIR/core/symlink.sh" validate \
  "$ROOT_DIR/dotfiles/git/.gitconfig" "$HOME/.gitconfig" \
  "$ROOT_DIR/dotfiles/git/.gitignore_global" "$HOME/.gitignore_global"; then
  exit 1
fi
printf 'Git validated.\n'
