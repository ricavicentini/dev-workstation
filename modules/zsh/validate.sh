#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
  printf 'Error: HOME must reference an existing directory.\n' >&2
  exit 1
fi

printf 'Validating Zsh...\n'
if ! bash "$ROOT_DIR/core/symlink.sh" validate \
  "$ROOT_DIR/dotfiles/zsh/.zshrc" "$HOME/.zshrc"; then
  exit 1
fi
printf 'Zsh validated.\n'
