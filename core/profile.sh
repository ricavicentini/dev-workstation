#!/usr/bin/env bash

set -uo pipefail

usage() {
  printf 'Usage: profile.sh <validate|get> <profile-file> [key]\n' >&2
}

log_error() {
  printf 'Error: %s\n' "$*" >&2
}

validate_profile() {
  local profile_file="$1"
  local line
  local key
  local value
  local -a required_keys=(homebrew_prerequisites package_provider bash_runtime)
  local -a seen_keys=()
  local required_key

  [[ -f "$profile_file" && -r "$profile_file" ]] || {
    log_error "profile is not readable: $profile_file"
    return 1
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ "$line" != *=* ]]; then
      log_error "invalid profile entry: $line"
      return 1
    fi

    key="${line%%=*}"
    value="${line#*=}"
    if [[ -z "$key" || -z "$value" || "$key" =~ [^a-z_] || "$value" =~ [^a-z0-9-] ]]; then
      log_error "invalid profile entry: $line"
      return 1
    fi

    for required_key in "${seen_keys[@]}"; do
      if [[ "$required_key" == "$key" ]]; then
        log_error "profile key is duplicated: $key"
        return 1
      fi
    done
    seen_keys+=("$key")

    case "$key:$value" in
      homebrew_prerequisites:apt-get|homebrew_prerequisites:installer|package_provider:brew|bash_runtime:system|bash_runtime:brew)
        ;;
      homebrew_prerequisites:*|package_provider:*|bash_runtime:*)
        log_error "unsupported value for $key: $value"
        return 1
        ;;
      *)
        log_error "unknown profile key: $key"
        return 1
        ;;
    esac

  done < "$profile_file"

  for required_key in "${required_keys[@]}"; do
    local key_seen=0
    for key in "${seen_keys[@]}"; do
      [[ "$key" == "$required_key" ]] && key_seen=1
    done
    if ((key_seen == 0)); then
      log_error "profile key is required: $required_key"
      return 1
    fi
  done

}

get_value() {
  local profile_file="$1"
  local requested_key="$2"
  local line
  local key

  [[ -f "$profile_file" && -r "$profile_file" ]] || {
    log_error "profile is not readable: $profile_file"
    return 1
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* || "$line" != "$requested_key="* ]] && continue

    key="${line%%=*}"
    if [[ "$key" == "$requested_key" ]]; then
      printf '%s\n' "${line#*=}"
      return 0
    fi
  done < "$profile_file"

  log_error "profile key was not found: $requested_key"
  return 1
}

main() {
  local action="${1:-}"
  local profile_file="${2:-}"

  case "$action" in
    validate)
      (($# == 2)) || { usage; return 2; }
      validate_profile "$profile_file"
      ;;
    get)
      (($# == 3)) || { usage; return 2; }
      get_value "$profile_file" "$3"
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
