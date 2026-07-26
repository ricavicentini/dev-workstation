#!/bin/bash

set -uo pipefail

printf '%s\n' 'installer-ran' >> "${HOMEBREW_TEST_INSTALL_LOG:?}"
mkdir -p "${HOMEBREW_TEST_PREFIX:?}/bin"
mkdir -p "${HOMEBREW_TEST_PREFIX:?}/formula"
printf '%s\n' '#!/bin/bash' \
  'case "${1:-}" in' \
  '  --version) printf "Homebrew test\n" ;;' \
  '  --prefix) printf "%s\n" "${HOMEBREW_TEST_PREFIX:?}" ;;' \
  '  list)' \
  '    [[ "${2:-}" == "--formula" && -n "${3:-}" ]] || exit 64' \
  '    [[ -f "${HOMEBREW_TEST_PREFIX:?}/formula/$3" ]] || exit 1' \
  '    printf "%s\n" "$3"' \
  '    ;;' \
  '  install)' \
  '    [[ -n "${2:-}" ]] || exit 64' \
  '    printf "%s\n" "brew install $2" >> "${HOMEBREW_TEST_BREW_LOG:-/dev/null}"' \
  '    [[ "${HOMEBREW_TEST_INSTALL_FAIL:-}" != "$2" ]] || exit 70' \
  '    if [[ "${HOMEBREW_TEST_INSTALL_WITHOUT_FORMULA:-}" != "$2" ]]; then' \
  '      : > "${HOMEBREW_TEST_PREFIX:?}/formula/$2"' \
  '    fi' \
  '    case "$2" in' \
  '      bash)' \
  '        printf "%s\n" "#!/bin/bash" "set -uo pipefail" "printf \"%s\\n\" \"\${1:-}\" >> \"\${HOMEBREW_TEST_BASH_LOG:-/dev/null}\"" "exec \"\${HOMEBREW_TEST_REAL_BASH:?}\" \"\$@\"" > "${HOMEBREW_TEST_PREFIX:?}/bin/bash"' \
  '        ;;' \
  '      git)' \
  '        printf "#!/bin/bash\nprintf '\''git version test\\n'\''\n" > "${HOMEBREW_TEST_PREFIX:?}/bin/git"' \
  '        ;;' \
  '      gh)' \
  '        printf "#!/bin/bash\nif [[ \"\${1:-}\" == '\''--version'\'' ]]; then printf '\''gh version test\\n'\''; else printf '\''gh test\\n'\''; fi\n" > "${HOMEBREW_TEST_PREFIX:?}/bin/gh"' \
  '        ;;' \
  '      zsh)' \
  '        printf "#!/bin/bash\nif [[ \"\${1:-}\" == '\''-n'\'' ]]; then exit \"\${HOMEBREW_TEST_ZSH_SYNTAX_STATUS:-0}\"; fi\nprintf '\''zsh test\\n'\''\n" > "${HOMEBREW_TEST_PREFIX:?}/bin/zsh"' \
  '        ;;' \
  '      *)' \
  '        printf "#!/bin/bash\nexit 0\n" > "${HOMEBREW_TEST_PREFIX:?}/bin/$2"' \
  '        ;;' \
  '    esac' \
  '    /bin/chmod +x "${HOMEBREW_TEST_PREFIX:?}/bin/$2"' \
  '    ;;' \
  '  shellenv) printf "export PATH=%s/bin:\$PATH\n" "${HOMEBREW_TEST_PREFIX:?}" ;;' \
  '  *) exit 64 ;;' \
  'esac' > "${HOMEBREW_TEST_PREFIX:?}/bin/brew"
/bin/chmod +x "${HOMEBREW_TEST_PREFIX:?}/bin/brew"
