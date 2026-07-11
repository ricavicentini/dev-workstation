#!/usr/bin/env bash

set -uo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/../.." && pwd)"

exec bash "$ROOT_DIR/core/module.sh" "$MODULE_DIR" "$@"
