#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT_DIR/tests/module-lifecycle-test.sh" && \
  bash "$ROOT_DIR/tests/symlink-test.sh" && \
  bash "$ROOT_DIR/tests/modules-test.sh" && \
  bash "$ROOT_DIR/tests/profile-test.sh" && \
  bash "$ROOT_DIR/tests/homebrew-test.sh" && \
  bash "$ROOT_DIR/tests/bootstrap-test.sh"
