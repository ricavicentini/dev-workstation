#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

printf 'Validating GitHub CLI...\n'
if ! bash "$ROOT_DIR/core/homebrew.sh" validate gh gh; then
  exit 1
fi

if ! gh --version >/dev/null; then
  printf 'Error: gh executable is not functional.\n' >&2
  exit 1
fi

printf 'GitHub CLI validated.\n'
