#!/bin/bash

set -uo pipefail

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

mkdir -p "$SDKMAN_DIR/bin" "$SDKMAN_DIR/candidates/java" "$SDKMAN_DIR/var"
printf '%s\n' 'installer-ran' >> "${SDKMAN_TEST_INSTALL_LOG:?}"

cat > "$SDKMAN_DIR/bin/sdkman-init.sh" <<'EOF'
#!/usr/bin/env bash

if [ -z "$SDKMAN_CANDIDATES_API" ]; then
  export SDKMAN_CANDIDATES_API='https://api.sdkman.io/2'
fi

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
SDKMAN_TEST_COMMAND_LOG="${SDKMAN_TEST_COMMAND_LOG:-/dev/null}"
export SDKMAN_DIR

if [[ -L "$SDKMAN_DIR/candidates/java/current" || -d "$SDKMAN_DIR/candidates/java/current" ]]; then
  export PATH="$SDKMAN_DIR/candidates/java/current/bin:$PATH"
fi

sdk() {
  local command="$1"
  local candidate="$2"
  local version="${3:-}"
  local major

  case "$command" in
    version)
      printf 'SDKMAN! test version\n'
      ;;
    list)
      [[ "$candidate" == 'java' ]] || return 64
      printf '================================================================================\n'
      printf 'Available Java Versions\n'
      if [[ -d "$SDKMAN_DIR/candidates/java" ]]; then
        find "$SDKMAN_DIR/candidates/java" -mindepth 1 -maxdepth 1 -type d ! -name current -exec basename {} \; | sort | while IFS= read -r installed; do
          if [[ -L "$SDKMAN_DIR/candidates/java/current" && "$(readlink "$SDKMAN_DIR/candidates/java/current")" == "$installed" ]]; then
            printf ' > * %s\n' "$installed"
          else
            printf '     %s\n' "$installed"
          fi
        done
      fi
      ;;
    install)
      [[ "$candidate" == 'java' && -n "$version" ]] || return 64
      printf 'sdk install java %s\n' "$version" >> "$SDKMAN_TEST_COMMAND_LOG"
      mkdir -p "$SDKMAN_DIR/candidates/java/$version/bin"
      major="${version%%.*}"
      cat > "$SDKMAN_DIR/candidates/java/$version/bin/java" <<JAVA_EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == '-version' ]]; then
  printf 'openjdk version "%s"\n' "$version"
  exit 0
fi
printf 'java test %s\n' "$version"
JAVA_EOF
      chmod +x "$SDKMAN_DIR/candidates/java/$version/bin/java"
      ;;
    default)
      [[ "$candidate" == 'java' && -n "$version" ]] || return 64
      [[ -d "$SDKMAN_DIR/candidates/java/$version" ]] || return 1
      printf 'sdk default java %s\n' "$version" >> "$SDKMAN_TEST_COMMAND_LOG"
      /bin/rm -f "$SDKMAN_DIR/candidates/java/current"
      /bin/ln -s "$version" "$SDKMAN_DIR/candidates/java/current"
      printf '%s\n' "$version" > "$SDKMAN_DIR/var/default-java"
      export PATH="$SDKMAN_DIR/candidates/java/current/bin:$PATH"
      ;;
    current)
      [[ "$candidate" == 'java' ]] || return 64
      if [[ -L "$SDKMAN_DIR/candidates/java/current" ]]; then
        printf 'Current default java version %s\n' "$(readlink "$SDKMAN_DIR/candidates/java/current")"
      else
        printf 'No current version of java configured.\n' >&2
        return 1
      fi
      ;;
    *)
      return 64
      ;;
  esac
}
EOF

chmod +x "$SDKMAN_DIR/bin/sdkman-init.sh"
