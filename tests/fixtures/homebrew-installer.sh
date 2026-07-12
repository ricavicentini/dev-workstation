#!/bin/bash

set -uo pipefail

printf '%s\n' 'installer-ran' >> "${HOMEBREW_TEST_INSTALL_LOG:?}"
mkdir -p "${HOMEBREW_TEST_PREFIX:?}/bin"
printf '%s\n' '#!/bin/bash' \
  'case "${1:-}" in' \
  '  --version) printf "Homebrew test\n" ;;' \
  '  --prefix) printf "%s\n" "${HOMEBREW_TEST_PREFIX:?}" ;;' \
  '  install)' \
  '    [[ "${2:-}" == bash ]] || exit 64' \
  '    printf "#!/bin/bash\nexit 0\n" > "${HOMEBREW_TEST_PREFIX:?}/bin/bash"' \
  '    /bin/chmod +x "${HOMEBREW_TEST_PREFIX:?}/bin/bash"' \
  '    ;;' \
  '  shellenv) printf "export PATH=%s/bin:\$PATH\n" "${HOMEBREW_TEST_PREFIX:?}" ;;' \
  '  *) exit 64 ;;' \
  'esac' > "${HOMEBREW_TEST_PREFIX:?}/bin/brew"
/bin/chmod +x "${HOMEBREW_TEST_PREFIX:?}/bin/brew"
