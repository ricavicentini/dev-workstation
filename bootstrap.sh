#!/usr/bin/env bash

set -euo pipefail

echo "======================================"
echo " Dev Workstation Bootstrap"
echo "======================================"

bash modules/git/module.sh configure
bash modules/git/module.sh validate
bash modules/zsh/module.sh all

echo
echo "Bootstrap completed."
echo "Run 'source ~/.zshrc' from an existing Zsh session to reload it now."
