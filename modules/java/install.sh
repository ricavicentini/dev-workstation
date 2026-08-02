#!/usr/bin/env bash

set -uo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$MODULE_DIR/common.sh"

printf 'Installing Java with SDKMAN...\n'
require_home || exit 1
require_brew_provider || exit 1
load_java_versions || exit 1
install_sdkman || exit 1
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
  if java_version_installed "$java_version"; then
    printf 'Java %s is already installed with SDKMAN.\n' "$java_version"
    continue
  fi

  printf 'Installing Java %s with SDKMAN...\n' "$java_version"
  if ! run_sdk install java "$java_version"; then
    log_error "SDKMAN failed to install Java: $java_version"
    exit 1
  fi
done

current_version="$(current_java_version || true)"
if [[ "$current_version" == "$JAVA_DEFAULT" ]]; then
  printf 'Java %s is already the SDKMAN default.\n' "$JAVA_DEFAULT"
else
  printf 'Setting Java %s as the SDKMAN default...\n' "$JAVA_DEFAULT"
  if ! run_sdk default java "$JAVA_DEFAULT"; then
    log_error "SDKMAN failed to set the Java default: $JAVA_DEFAULT"
    exit 1
  fi
fi

# Re-source SDKMAN after the default is set so the current shell picks up
# the active Java path even on the first installation.
source_sdkman || exit 1

if ! java -version >/dev/null 2>&1; then
  log_error 'java executable is not functional after SDKMAN installation.'
  exit 1
fi

printf 'Java installed with SDKMAN.\n'
