#!/usr/bin/env bash

set -euo pipefail

echo "======================================"
echo " Dev Workstation Bootstrap"
echo "======================================"

bash modules/dotfiles/module.sh configure
bash modules/dotfiles/module.sh validate
bash modules/zsh/module.sh configure
bash modules/zsh/module.sh validate

echo
echo "Bootstrap completed."
echo "Run 'source ~/.zshrc' from an existing Zsh session to reload it now."
