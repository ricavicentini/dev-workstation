#!/usr/bin/env bash

set -euo pipefail

echo "======================================"
echo " Dev Workstation Bootstrap"
echo "======================================"

bash scripts/link/dotfiles.sh

echo
echo "Bootstrap completed."
echo "Restart your terminal."
