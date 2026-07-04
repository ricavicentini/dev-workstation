#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT_DIR/tests/symlink-test.sh" && \
  bash "$ROOT_DIR/tests/modules-test.sh"
