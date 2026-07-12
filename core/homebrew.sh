#!/usr/bin/env bash

set -uo pipefail

INSTALLER_URL='https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'

log_error() {
  printf 'Error: %s\n' "$*" >&2
}

find_brew() {
  local candidate

  if [[ -n "${DEV_WORKSTATION_BREW_PATH:-}" ]]; then
    [[ -x "$DEV_WORKSTATION_BREW_PATH" ]] && printf '%s\n' "$DEV_WORKSTATION_BREW_PATH" && return 0
    return 1
  fi

  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  for candidate in /home/linuxbrew/.linuxbrew/bin/brew /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done

  return 1
}

install_ubuntu_prerequisites() {
  command -v sudo >/dev/null 2>&1 || { log_error 'sudo is required to prepare Homebrew on Ubuntu.'; return 1; }
  command -v apt-get >/dev/null 2>&1 || { log_error 'apt-get is required to prepare Homebrew on Ubuntu.'; return 1; }

  printf 'Preparing Homebrew prerequisites with apt-get...\n' >&2
  sudo apt-get update >&2
  sudo apt-get install -y build-essential procps curl file git >&2
}

install_homebrew() {
  local installer
  local status

  command -v curl >/dev/null 2>&1 || { log_error 'curl is required to install Homebrew.'; return 1; }
  [[ -x /bin/bash ]] || { log_error '/bin/bash is required to install Homebrew.'; return 1; }
  installer="$(mktemp)" || return 1

  printf 'Downloading the Homebrew installer...\n' >&2
  if ! curl -fsSL "$INSTALLER_URL" -o "$installer"; then
    /bin/rm -f -- "$installer"
    return 1
  fi
  printf 'Running the Homebrew installer...\n' >&2
  /bin/bash "$installer" >&2
  status=$?
  /bin/rm -f -- "$installer"
  return "$status"
}

ensure() {
  local prerequisites="$1"
  local bash_runtime="$2"
  local brew_path
  local brew_prefix

  case "$prerequisites" in
    apt-get|installer)
      ;;
    *)
      log_error "unsupported Homebrew prerequisite strategy: $prerequisites"
      return 2
      ;;
  esac

  case "$bash_runtime" in
    system|brew)
      ;;
    *)
      log_error "unsupported Bash runtime strategy: $bash_runtime"
      return 2
      ;;
  esac

  if ! brew_path="$(find_brew)"; then
    [[ "$prerequisites" != 'apt-get' ]] || install_ubuntu_prerequisites || return 1
    install_homebrew || { log_error 'Homebrew installation failed.'; return 1; }
    brew_path="$(find_brew)" || { log_error 'Homebrew installation completed, but brew was not found.'; return 1; }
  fi

  "$brew_path" --version >/dev/null || { log_error 'Homebrew is not functional.'; return 1; }
  brew_prefix="$("$brew_path" --prefix)" || return 1

  if [[ "$bash_runtime" == 'brew' && ! -x "$brew_prefix/bin/bash" ]]; then
    printf 'Installing Bash with Homebrew...\n' >&2
    "$brew_path" install bash || return 1
  fi

  printf '%s\n' "$brew_path"
}

if (($# != 3)) || [[ "$1" != 'ensure' ]]; then
  printf 'Usage: homebrew.sh ensure <apt-get|installer> <system|brew>\n' >&2
  exit 2
fi

ensure "$2" "$3"
