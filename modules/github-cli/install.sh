#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ "${DEV_WORKSTATION_PACKAGE_PROVIDER:-}" != 'brew' ]]; then
  printf 'Error: GitHub CLI installation requires DEV_WORKSTATION_PACKAGE_PROVIDER=brew.\n' >&2
  exit 1
fi

bash "$ROOT_DIR/core/homebrew.sh" install gh &&
  bash "$ROOT_DIR/core/homebrew.sh" validate gh gh
