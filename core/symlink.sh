#!/usr/bin/env bash

set -uo pipefail

ACTION=''
SOURCES=()
TARGETS=()
TRANSACTION_ACTIVE=0
CHANGED_TARGETS=()
BACKUP_PATHS=()

log_error() {
  printf 'Error: %s\n' "$*" >&2
}

usage() {
  printf 'Usage: %s <apply|validate> <source> <target> [<source> <target>...]\n' "$0" >&2
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    log_error "required command not found: $command_name"
    return 1
  fi
}

parse_arguments() {
  local action="${1:-}"

  case "$action" in
    apply|validate)
      ACTION="$action"
      ;;
    *)
      usage
      return 2
      ;;
  esac

  shift

  if (($# < 2 || $# % 2 != 0)); then
    usage
    return 2
  fi

  while (($# > 0)); do
    SOURCES+=("$1")
    TARGETS+=("$2")
    shift 2
  done
}

preflight() {
  local mutating="$1"
  local index
  local source
  local target
  local parent
  local command_name
  local -A seen_targets=()

  require_command readlink || return 1
  require_command dirname || return 1

  if [[ "$mutating" == 'true' ]]; then
    for command_name in date ln mv rm; do
      require_command "$command_name" || return 1
    done
  fi

  for index in "${!SOURCES[@]}"; do
    source="${SOURCES[$index]}"
    target="${TARGETS[$index]}"

    if [[ -z "$target" ]]; then
      log_error 'target must not be empty'
      return 1
    fi

    if [[ ! -f "$source" ]]; then
      log_error "managed source does not exist: $source"
      return 1
    fi

    if [[ -n "${seen_targets[$target]+present}" ]]; then
      log_error "target is managed more than once: $target"
      return 1
    fi
    seen_targets["$target"]=1

    if [[ "$mutating" == 'true' ]]; then
      parent="$(dirname -- "$target")" || return 1

      if [[ ! -d "$parent" ]]; then
        log_error "target directory does not exist: $parent"
        return 1
      fi

      if [[ ! -w "$parent" ]]; then
        log_error "target directory is not writable: $parent"
        return 1
      fi
    fi
  done
}

is_expected_link() {
  local source="$1"
  local target="$2"

  [[ -L "$target" ]] || return 1
  [[ "$(readlink -- "$target")" == "$source" ]]
}

select_backup_path() {
  local target="$1"
  local timestamp
  local candidate
  local suffix=0

  timestamp="$(date +%Y%m%d%H%M%S)" || return 1
  candidate="${target}.backup.${timestamp}"

  while [[ -e "$candidate" || -L "$candidate" ]]; do
    suffix=$((suffix + 1))
    candidate="${target}.backup.${timestamp}.${suffix}"
  done

  BACKUP_PATH="$candidate"
}

begin_transaction() {
  CHANGED_TARGETS=()
  BACKUP_PATHS=()
  TRANSACTION_ACTIVE=1
}

commit_transaction() {
  TRANSACTION_ACTIVE=0
  CHANGED_TARGETS=()
  BACKUP_PATHS=()
}

rollback_transaction() {
  local index
  local target
  local backup
  local rollback_failed=0

  printf 'Rolling back symbolic-link changes...\n' >&2

  for ((index = ${#CHANGED_TARGETS[@]} - 1; index >= 0; index--)); do
    target="${CHANGED_TARGETS[$index]}"
    backup="${BACKUP_PATHS[$index]}"

    if [[ -n "$backup" ]]; then
      if [[ ! -e "$backup" && ! -L "$backup" ]]; then
        if [[ -e "$target" || -L "$target" ]]; then
          continue
        fi

        log_error "backup missing during rollback: $backup"
        rollback_failed=1
        continue
      fi

      if [[ -e "$target" || -L "$target" ]]; then
        if ! rm -f -- "$target"; then
          log_error "could not remove changed target during rollback: $target"
          log_error "backup preserved at: $backup"
          rollback_failed=1
          continue
        fi
      fi

      if ! mv -- "$backup" "$target"; then
        log_error "could not restore target during rollback: $target"
        log_error "backup preserved at: $backup"
        rollback_failed=1
      fi
    elif [[ -e "$target" || -L "$target" ]]; then
      if ! rm -f -- "$target"; then
        log_error "could not remove changed target during rollback: $target"
        rollback_failed=1
      fi
    fi
  done

  TRANSACTION_ACTIVE=0
  CHANGED_TARGETS=()
  BACKUP_PATHS=()

  if ((rollback_failed != 0)); then
    log_error 'rollback completed with recovery errors'
    return 1
  fi

  printf 'Rollback completed.\n' >&2
}

handle_exit() {
  local status="$1"

  trap - EXIT INT TERM
  
  ((TRANSACTION_ACTIVE != 0)) && ! rollback_transaction && status=1

  exit "$status"
}

handle_signal() {
  local signal_name="$1"
  local status="$2"

  log_error "received $signal_name; aborting symbolic-link changes"
  exit "$status"
}

apply_links() {
  local index
  local source
  local target
  local backup

  for index in "${!SOURCES[@]}"; do
    source="${SOURCES[$index]}"
    target="${TARGETS[$index]}"
    backup=''

    if is_expected_link "$source" "$target"; then
      continue
    fi

    if [[ -e "$target" || -L "$target" ]]; then
      if ! select_backup_path "$target"; then
        log_error "could not select a backup path for: $target"
        return 1
      fi

      backup="$BACKUP_PATH"
      CHANGED_TARGETS+=("$target")
      BACKUP_PATHS+=("$backup")

      if ! mv -- "$target" "$backup"; then
        log_error "could not back up target: $target"
        return 1
      fi
    else
      CHANGED_TARGETS+=("$target")
      BACKUP_PATHS+=("")
    fi

    if ! ln -s -- "$source" "$target"; then
      log_error "could not create symbolic link: $target"
      return 1
    fi
  done
}

validate_links() {
  local index
  local source
  local target
  local validation_failed=0

  for index in "${!SOURCES[@]}"; do
    source="${SOURCES[$index]}"
    target="${TARGETS[$index]}"

    if ! is_expected_link "$source" "$target"; then
      log_error "expected symbolic link $target -> $source"
      validation_failed=1
    fi
  done

  if ((validation_failed != 0)); then
    return 1
  fi

}

run_apply() {
  preflight true || return 1
  begin_transaction

  apply_links || return 1
  validate_links || return 1

  commit_transaction
}

main() {
  parse_arguments "$@" || return $?

  case "$ACTION" in
    apply)
      run_apply
      ;;
    validate)
      preflight false && validate_links
      ;;
  esac
}

trap 'handle_exit $?' EXIT
trap 'handle_signal INT 130' INT
trap 'handle_signal TERM 143' TERM

main "$@"
