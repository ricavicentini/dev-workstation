#!/usr/bin/env bash

set -uo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$MODULE_DIR/common.sh"

printf 'Validating Java...\n'
require_home || exit 1
load_java_versions || exit 1
source_sdkman || exit 1

if ! run_sdk version >/dev/null; then
  log_error 'sdk command is not functional.'
  exit 1
fi

if ! run_sdk list java >/dev/null; then
  log_error 'sdk list java failed.'
  exit 1
fi

for java_version in "${JAVA_VERSIONS[@]}"; do
  if ! java_version_installed "$java_version"; then
    log_error "Java version is not installed with SDKMAN: $java_version"
    exit 1
  fi
done

current_version="$(current_java_version || true)"
if [[ "$current_version" != "$JAVA_DEFAULT" ]]; then
  log_error "Java default version is not active: expected $JAVA_DEFAULT, got ${current_version:-none}"
  exit 1
fi

if ! java -version >/dev/null 2>&1; then
  log_error 'java executable is not functional.'
  exit 1
fi

printf 'Java validated.\n'
