#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

backup_if_exists() {
  local target="$1"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv "$target" "${target}.backup.$(date +%Y%m%d%H%M%S)"
  fi
}

link_file() {
  local source="$1"
  local target="$2"

  backup_if_exists "$target"
  ln -sfn "$source" "$target"
}

echo "Linking dotfiles..."

link_file "$ROOT_DIR/zsh/.zshrc" "$HOME/.zshrc"
link_file "$ROOT_DIR/git/.gitconfig" "$HOME/.gitconfig"
link_file "$ROOT_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

echo "Dotfiles linked."
