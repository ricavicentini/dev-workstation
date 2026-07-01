#!/usr/bin/env bash

set -euo pipefail

echo "Starting dev workstation bootstrap..."

sudo apt update

sudo apt install -y \
  curl \
  wget \
  git \
  unzip \
  zip \
  zsh \
  fzf \
  ripgrep \
  fd-find \
  bat

echo "Bootstrap completed."

