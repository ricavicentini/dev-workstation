#!/usr/bin/env bash

set -euo pipefail

echo "Installing Zsh..."

sudo apt install -y zsh

echo "Changing default shell..."

chsh -s "$(which zsh)"

echo "Done."
