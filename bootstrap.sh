#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$ROOT_DIR/profiles"
PROFILE_SCRIPT="$ROOT_DIR/core/profile.sh"
HOMEBREW_SCRIPT="$ROOT_DIR/core/homebrew.sh"

usage() {
  printf 'Usage: bootstrap.sh <ubuntu|macos>\n' >&2
}

log_error() {
  printf 'Error: %s\n' "$*" >&2
}

if (($# != 1)) || [[ ! "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  usage
  exit 2
fi

PROFILE_FILE="$PROFILE_DIR/$1.conf"
if ! bash "$PROFILE_SCRIPT" validate "$PROFILE_FILE"; then
  exit 1
fi

HOME_BREW_PREREQUISITES="$(bash "$PROFILE_SCRIPT" get "$PROFILE_FILE" homebrew_prerequisites)"
PACKAGE_PROVIDER="$(bash "$PROFILE_SCRIPT" get "$PROFILE_FILE" package_provider)"
BASH_RUNTIME="$(bash "$PROFILE_SCRIPT" get "$PROFILE_FILE" bash_runtime)"
BREW_PATH="$(bash "$HOMEBREW_SCRIPT" ensure "$HOME_BREW_PREREQUISITES" "$BASH_RUNTIME")"
BREW_PREFIX="$("$BREW_PATH" --prefix)"
export PATH="$BREW_PREFIX/bin:$PATH"

if [[ "$BASH_RUNTIME" == 'brew' && "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  BREW_BASH="$BREW_PREFIX/bin/bash"
  [[ -x "$BREW_BASH" ]] || { log_error "Bash was not found at: $BREW_BASH"; exit 1; }
  exec "$BREW_BASH" "$ROOT_DIR/bootstrap.sh" "$@"
fi

echo "======================================"
echo " Dev Workstation Bootstrap"
echo "======================================"

bash "$ROOT_DIR/modules/git/module.sh" configure
bash "$ROOT_DIR/modules/git/module.sh" validate
DEV_WORKSTATION_PACKAGE_PROVIDER="$PACKAGE_PROVIDER" bash "$ROOT_DIR/modules/zsh/module.sh" all

echo
echo "Bootstrap completed."
echo "Run 'source ~/.zshrc' from an existing Zsh session to reload it now."
