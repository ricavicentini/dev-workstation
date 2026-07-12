#!/usr/bin/env bash

set -uo pipefail

log_error() {
  printf 'Error: %s\n' "$*" >&2
}

if command -v zsh >/dev/null 2>&1; then
  printf 'Zsh is already installed.\n'
  exit 0
fi

if ! command -v sudo >/dev/null 2>&1; then
  log_error 'sudo is required to install Zsh.'
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  log_error 'apt-get is required to install Zsh.'
  exit 1
fi

printf 'Installing Zsh with apt-get...\n'
if ! sudo apt-get install -y zsh; then
  log_error 'Zsh installation failed.'
  exit 1
fi

if ! command -v zsh >/dev/null 2>&1; then
  log_error 'Zsh installation completed, but the zsh executable was not found.'
  exit 1
fi

printf 'Zsh installed.\n'
