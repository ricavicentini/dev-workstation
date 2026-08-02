#!/usr/bin/env bash

set -uo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="$MODULE_DIR/versions.conf"

log_error() {
  printf 'Error: %s\n' "$*" >&2
}

require_home() {
  if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
    log_error 'HOME must reference an existing directory.'
    return 1
  fi
}

require_brew_provider() {
  if [[ "${DEV_WORKSTATION_PACKAGE_PROVIDER:-}" != 'brew' ]]; then
    log_error 'Java installation requires DEV_WORKSTATION_PACKAGE_PROVIDER=brew.'
    return 1
  fi
}

require_curl() {
  command -v curl >/dev/null 2>&1 || {
    log_error 'curl is required to install SDKMAN.'
    return 1
  }
}

sdkman_dir() {
  if [[ -n "${SDKMAN_DIR:-}" ]]; then
    printf '%s\n' "$SDKMAN_DIR"
  else
    printf '%s\n' "$HOME/.sdkman"
  fi
}

sdkman_init_script() {
  printf '%s/bin/sdkman-init.sh\n' "$(sdkman_dir)"
}

sdkman_installed() {
  [[ -r "$(sdkman_init_script)" ]]
}

install_sdkman() {
  local installer_url="${DEV_WORKSTATION_SDKMAN_INSTALL_URL:-https://get.sdkman.io?ci=true&rcupdate=false}"

  if sdkman_installed; then
    printf 'SDKMAN is already installed.\n'
    return 0
  fi

  require_curl || return 1
  printf 'Installing SDKMAN...\n'
  curl -s "$installer_url" | bash >/dev/null || {
    log_error 'SDKMAN installation failed.'
    return 1
  }

  sdkman_installed || {
    log_error "SDKMAN installation completed, but the init script was not found: $(sdkman_init_script)"
    return 1
  }
  printf 'SDKMAN installed.\n'
}

source_sdkman() {
  local init_script
  local source_status=0

  init_script="$(sdkman_init_script)"
  [[ -r "$init_script" ]] || {
    log_error "SDKMAN init script is not readable: $init_script"
    return 1
  }

  with_nounset_compat source_status source "$init_script"

  ((source_status == 0)) || {
    log_error "SDKMAN initialization failed while sourcing: $init_script"
    return 1
  }

  command -v sdk >/dev/null 2>&1 || {
    log_error 'sdk command is not available after SDKMAN initialization.'
    return 1
  }
}

with_nounset_compat() {
  local __resultvar="$1"
  shift
  local nounset_enabled=0
  local command_status=0

  if [[ "$-" == *u* ]]; then
    nounset_enabled=1
    set +u
  fi

  "$@"
  command_status=$?

  if ((nounset_enabled == 1)); then
    set -u
  fi

  printf -v "$__resultvar" '%s' "$command_status"
}

run_sdk() {
  local sdk_status=0

  with_nounset_compat sdk_status sdk "$@"
  return "$sdk_status"
}

load_java_versions() {
  local line
  local key
  local value
  local version
  local found_default=0
  local index

  [[ -f "$VERSIONS_FILE" && -r "$VERSIONS_FILE" ]] || {
    log_error "Java versions file is not readable: $VERSIONS_FILE"
    return 1
  }

  JAVA_DEFAULT=''
  JAVA_VERSIONS=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == *=* ]] || {
      log_error "invalid Java versions entry: $line"
      return 1
    }

    key="${line%%=*}"
    value="${line#*=}"
    [[ -n "$key" && -n "$value" ]] || {
      log_error "invalid Java versions entry: $line"
      return 1
    }

    case "$key" in
      java_default)
        [[ -z "$JAVA_DEFAULT" ]] || {
          log_error 'Java versions file duplicates java_default.'
          return 1
        }
        JAVA_DEFAULT="$value"
        ;;
      java_version)
        for version in "${JAVA_VERSIONS[@]}"; do
          [[ "$version" != "$value" ]] || {
            log_error "Java versions file duplicates java_version: $value"
            return 1
          }
        done
        JAVA_VERSIONS+=("$value")
        ;;
      *)
        log_error "unknown Java versions key: $key"
        return 1
        ;;
    esac
  done < "$VERSIONS_FILE"

  [[ -n "$JAVA_DEFAULT" ]] || {
    log_error 'Java versions file requires java_default.'
    return 1
  }
  ((${#JAVA_VERSIONS[@]} > 0)) || {
    log_error 'Java versions file requires at least one java_version.'
    return 1
  }

  for index in "${!JAVA_VERSIONS[@]}"; do
    if [[ "${JAVA_VERSIONS[$index]}" == "$JAVA_DEFAULT" ]]; then
      found_default=1
    fi
  done

  ((found_default == 1)) || {
    log_error "Java default version is not declared as java_version: $JAVA_DEFAULT"
    return 1
  }
}

java_version_installed() {
  local version="$1"

  [[ -d "$(sdkman_dir)/candidates/java/$version" ]]
}

current_java_version() {
  local current_output
  local current_version

  current_output="$(run_sdk current java 2>/dev/null)" || return 1
  current_version="$(printf '%s\n' "$current_output" | sed -n \
    -e 's/^Using java version //p' \
    -e 's/^Current default java version //p' | head -n 1)"
  [[ -n "$current_version" ]] || return 1
  printf '%s\n' "$current_version"
}
