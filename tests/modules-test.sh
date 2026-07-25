#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_MODULE="$ROOT_DIR/modules/git/module.sh"
ZSH_MODULE="$ROOT_DIR/modules/zsh/module.sh"
BOOTSTRAP="$ROOT_DIR/bootstrap.sh"
FIXTURE_BIN="$ROOT_DIR/tests/fixtures/bin"
FIXTURE_INSTALLER="$ROOT_DIR/tests/fixtures/homebrew-installer.sh"
REAL_LN="$(command -v ln)"
REAL_MV="$(command -v mv)"
REAL_RM="$(command -v rm)"
REAL_BASH="$(command -v bash)"
TEST_ROOT="$(mktemp -d)"
TEST_COUNT=0

cleanup() {
  "$REAL_RM" -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf 'ok %d - %s\n' "$TEST_COUNT" "$1"
}

new_home() {
  local name="$1"
  local home="$TEST_ROOT/$name"

  mkdir -p "$home"
  printf '%s\n' "$home"
}

assert_link() {
  local target="$1"
  local source="$2"

  [[ -L "$target" ]] || fail "$target is not a symbolic link"
  [[ "$(readlink "$target")" == "$source" ]] || fail "$target points to an unexpected source"
}

backup_files() {
  local target="$1"

  compgen -G "${target}.backup.*" || true
}

setup_homebrew() {
  local name="$1"
  local prefix="$TEST_ROOT/$name/prefix"

  mkdir -p "$TEST_ROOT/$name"
  HOMEBREW_TEST_PREFIX="$prefix" \
    HOMEBREW_TEST_INSTALL_LOG="$TEST_ROOT/$name/install.log" \
    "$REAL_BASH" "$FIXTURE_INSTALLER" || fail "Homebrew fixture setup failed for $name"
}

with_homebrew() {
  local name="$1"
  shift

  PATH="$TEST_ROOT/$name/prefix/bin:$PATH" \
    HOME="${HOME:-}" \
    DEV_WORKSTATION_PACKAGE_PROVIDER="${DEV_WORKSTATION_PACKAGE_PROVIDER:-}" \
    HOMEBREW_TEST_PREFIX="$TEST_ROOT/$name/prefix" \
    HOMEBREW_TEST_BREW_LOG="$TEST_ROOT/$name/brew.log" \
    HOMEBREW_TEST_INSTALL_FAIL="${HOMEBREW_TEST_INSTALL_FAIL:-}" \
    HOMEBREW_TEST_INSTALL_WITHOUT_FORMULA="${HOMEBREW_TEST_INSTALL_WITHOUT_FORMULA:-}" \
    HOMEBREW_TEST_ZSH_SYNTAX_STATUS="${HOMEBREW_TEST_ZSH_SYNTAX_STATUS:-0}" \
    DEV_WORKSTATION_BREW_PATH="$TEST_ROOT/$name/prefix/bin/brew" \
    "$@"
}

install_formula_fixture() {
  local name="$1"
  local formula="$2"

  with_homebrew "$name" "$TEST_ROOT/$name/prefix/bin/brew" install "$formula" >/dev/null || fail "fixture formula install failed: $formula"
  rm -f "$TEST_ROOT/$name/brew.log"
}

test_git_module_owns_only_git() {
  local home
  home="$(new_home git-ownership)"
  setup_homebrew git-ownership-brew
  install_formula_fixture git-ownership-brew git

  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'Git module configuration failed'
  HOME="$home" with_homebrew git-ownership-brew bash "$GIT_MODULE" validate >/dev/null || fail 'Git module validation failed'
  assert_link "$home/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
  assert_link "$home/.gitignore_global" "$ROOT_DIR/dotfiles/git/.gitignore_global"
  [[ ! -e "$home/.zshrc" && ! -L "$home/.zshrc" ]] || fail 'Git module changed .zshrc'
  pass 'Git module owns only Git assets'
}

test_zsh_module_owns_only_zsh() {
  local home
  home="$(new_home zsh-ownership)"
  setup_homebrew zsh-ownership-brew
  install_formula_fixture zsh-ownership-brew zsh

  HOME="$home" bash "$ZSH_MODULE" configure >/dev/null || fail 'Zsh configuration failed'
  HOME="$home" with_homebrew zsh-ownership-brew bash "$ZSH_MODULE" validate >/dev/null || fail 'Zsh validation failed'
  assert_link "$home/.zshrc" "$ROOT_DIR/dotfiles/zsh/.zshrc"
  [[ ! -e "$home/.gitconfig" && ! -L "$home/.gitconfig" ]] || fail 'Zsh module changed .gitconfig'
  [[ ! -e "$home/.gitignore_global" && ! -L "$home/.gitignore_global" ]] || fail 'Zsh module changed .gitignore_global'
  pass 'Zsh module owns only .zshrc'
}

test_zsh_install_is_idempotent_when_present() {
  local home
  home="$(new_home zsh-installed)"
  setup_homebrew zsh-installed-brew
  install_formula_fixture zsh-installed-brew zsh

  HOME="$home" DEV_WORKSTATION_PACKAGE_PROVIDER=brew \
    with_homebrew zsh-installed-brew bash "$ZSH_MODULE" install >/dev/null || fail 'installed Zsh was not accepted'
  [[ -z "$(find "$home" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail 'deferred installation changed HOME'
  [[ ! -e "$TEST_ROOT/zsh-installed-brew/brew.log" ]] || fail 'idempotent Zsh installation invoked Brew'
  pass 'Zsh installation is idempotent when the executable already exists'
}

test_zsh_install_uses_homebrew_when_absent() {
  local home
  home="$(new_home zsh-install)"
  setup_homebrew zsh-install-brew

  HOME="$home" DEV_WORKSTATION_PACKAGE_PROVIDER=brew \
    with_homebrew zsh-install-brew "$REAL_BASH" "$ROOT_DIR/modules/zsh/install.sh" >/dev/null || fail 'controlled Zsh installation failed'
  [[ "$(<"$TEST_ROOT/zsh-install-brew/brew.log")" == 'brew install zsh' ]] || fail 'Zsh installation did not invoke Brew'
  [[ -x "$TEST_ROOT/zsh-install-brew/prefix/bin/zsh" ]] || fail 'controlled installation did not provide zsh'
  pass 'Zsh installation invokes Homebrew when the formula is absent'
}

test_zsh_install_fails_without_brew_provider() {
  local home
  home="$(new_home zsh-no-provider)"

  if HOME="$home" "$REAL_BASH" "$ROOT_DIR/modules/zsh/install.sh" >/dev/null 2>&1; then
    fail 'Zsh installation succeeded without the Brew provider'
  fi
  [[ -z "$(find "$home" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail 'failed installation changed HOME'
  pass 'Zsh installation fails before mutation without the Brew provider'
}

test_zsh_validation_checks_syntax() {
  local home
  home="$(new_home zsh-invalid)"
  setup_homebrew zsh-invalid-brew
  install_formula_fixture zsh-invalid-brew zsh
  HOME="$home" bash "$ZSH_MODULE" configure >/dev/null || fail 'Zsh configuration failed'

  if HOMEBREW_TEST_ZSH_SYNTAX_STATUS=70 \
    HOME="$home" with_homebrew zsh-invalid-brew bash "$ZSH_MODULE" validate >/dev/null 2>&1; then
    fail 'invalid Zsh syntax unexpectedly validated'
  fi
  pass 'Zsh validation checks configuration syntax'
}

test_git_install_uses_homebrew_when_absent() {
  local home
  home="$(new_home git-install)"
  setup_homebrew git-install-brew

  HOME="$home" DEV_WORKSTATION_PACKAGE_PROVIDER=brew \
    with_homebrew git-install-brew "$REAL_BASH" "$ROOT_DIR/modules/git/install.sh" >/dev/null || fail 'controlled Git installation failed'
  [[ "$(<"$TEST_ROOT/git-install-brew/brew.log")" == 'brew install git' ]] || fail 'Git installation did not invoke Brew'
  [[ -x "$TEST_ROOT/git-install-brew/prefix/bin/git" ]] || fail 'controlled installation did not provide git'
  pass 'Git installation invokes Homebrew when the formula is absent'
}

test_git_install_fails_without_brew_provider() {
  local home
  home="$(new_home git-no-provider)"

  if HOME="$home" "$REAL_BASH" "$ROOT_DIR/modules/git/install.sh" >/dev/null 2>&1; then
    fail 'Git installation succeeded without the Brew provider'
  fi
  [[ -z "$(find "$home" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail 'failed Git installation changed HOME'
  pass 'Git installation fails before mutation without the Brew provider'
}

test_git_configuration_is_idempotent_and_preserves_existing_files() {
  local home
  local backups
  local backup
  local previous_found=0
  local replacement_found=0
  home="$(new_home git-idempotency)"

  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'initial Git configuration failed'
  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'repeated Git configuration failed'
  [[ -z "$(backup_files "$home/.gitconfig")" ]] || fail 'idempotent Git configuration created a .gitconfig backup'
  [[ -z "$(backup_files "$home/.gitignore_global")" ]] || fail 'idempotent Git configuration created a .gitignore_global backup'

  "$REAL_RM" -f -- "$home/.gitconfig"
  printf 'previous git configuration\n' > "$home/.gitconfig"
  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'Git configuration over an existing file failed'

  backups="$(backup_files "$home/.gitconfig")"
  [[ "$(printf '%s\n' "$backups" | sed '/^$/d' | wc -l)" -eq 1 ]] || fail 'existing .gitconfig did not create exactly one backup'
  [[ "$(<"$backups")" == 'previous git configuration' ]] || fail '.gitconfig backup content was not preserved'
  assert_link "$home/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
  assert_link "$home/.gitignore_global" "$ROOT_DIR/dotfiles/git/.gitignore_global"

  "$REAL_RM" -f -- "$home/.gitconfig"
  printf 'replacement git configuration\n' > "$home/.gitconfig"
  HOME="$home" bash "$GIT_MODULE" configure >/dev/null || fail 'second Git replacement failed'

  backups="$(backup_files "$home/.gitconfig")"
  [[ "$(printf '%s\n' "$backups" | sed '/^$/d' | wc -l)" -eq 2 ]] || fail 'Git replacements did not create unique backups'
  while IFS= read -r backup; do
    case "$(<"$backup")" in
      'previous git configuration')
        previous_found=1
        ;;
      'replacement git configuration')
        replacement_found=1
        ;;
    esac
  done <<< "$backups"
  ((previous_found == 1 && replacement_found == 1)) || fail 'unique Git backups did not preserve both versions'
  pass 'Git configuration is idempotent and creates unique recoverable backups'
}

test_git_failure_rolls_back_both_targets() {
  local home
  local output="$TEST_ROOT/git-rollback-output"
  home="$(new_home git-rollback)"
  printf 'original git configuration\n' > "$home/.gitconfig"

  if HOME="$home" \
    PATH="$FIXTURE_BIN:$PATH" \
    SYMLINK_TEST_LN_MODE='fail-second' \
    SYMLINK_TEST_LN_COUNT_FILE="$TEST_ROOT/git-rollback-count" \
    SYMLINK_TEST_REAL_LN="$REAL_LN" \
    SYMLINK_TEST_REAL_MV="$REAL_MV" \
    SYMLINK_TEST_REAL_RM="$REAL_RM" \
    SYMLINK_TEST_RM_FAIL=0 \
    bash "$GIT_MODULE" configure >"$output" 2>&1; then
    fail 'controlled Git failure unexpectedly succeeded'
  fi

  [[ ! -L "$home/.gitconfig" && "$(<"$home/.gitconfig")" == 'original git configuration' ]] || fail '.gitconfig was not restored'
  [[ ! -e "$home/.gitignore_global" && ! -L "$home/.gitignore_global" ]] || fail 'absent .gitignore_global was not restored'
  [[ -z "$(backup_files "$home/.gitconfig")" ]] || fail 'restored Git backup was left behind'
  pass 'Git configuration failure rolls back both targets'
}

test_bootstrap_configures_all_assets() {
  local home
  local output="$TEST_ROOT/bootstrap-output"
  local homebrew_root="$TEST_ROOT/bootstrap-homebrew"
  local homebrew_bin="$homebrew_root/bin"
  home="$(new_home bootstrap)"
  mkdir -p "$homebrew_bin"
  cp "$FIXTURE_BIN/apt-get" "$FIXTURE_BIN/curl" "$FIXTURE_BIN/sudo" "$homebrew_bin"
  chmod +x "$homebrew_bin/apt-get" "$homebrew_bin/curl" "$homebrew_bin/sudo"

  HOME="$home" \
    PATH="$homebrew_bin:$homebrew_root/prefix/bin:$PATH" \
    HOMEBREW_TEST_PREFIX="$homebrew_root/prefix" \
    HOMEBREW_TEST_CURL_LOG="$homebrew_root/curl.log" \
    HOMEBREW_TEST_INSTALL_LOG="$homebrew_root/install.log" \
    HOMEBREW_TEST_INSTALLER="$ROOT_DIR/tests/fixtures/homebrew-installer.sh" \
    HOMEBREW_TEST_APT_LOG="$homebrew_root/apt.log" \
    HOMEBREW_TEST_BREW_LOG="$homebrew_root/brew.log" \
    DEV_WORKSTATION_BREW_PATH="$homebrew_root/prefix/bin/brew" \
    bash "$BOOTSTRAP" ubuntu >"$output" || fail 'bootstrap failed'
  assert_link "$home/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
  assert_link "$home/.gitignore_global" "$ROOT_DIR/dotfiles/git/.gitignore_global"
  assert_link "$home/.zshrc" "$ROOT_DIR/dotfiles/zsh/.zshrc"
  grep -q '^Installing git with Homebrew\.\.\.$' "$output" || fail 'bootstrap did not identify Git installation'
  grep -q '^Configuring Git\.\.\.$' "$output" || fail 'bootstrap did not identify Git configuration'
  grep -q '^Git validated\.$' "$output" || fail 'bootstrap did not identify Git validation'
  grep -q '^Installing zsh with Homebrew\.\.\.$' "$output" || fail 'bootstrap did not identify Zsh installation'
  grep -q '^Configuring Zsh\.\.\.$' "$output" || fail 'bootstrap did not identify Zsh configuration'
  grep -q '^Zsh validated\.$' "$output" || fail 'bootstrap did not identify Zsh validation'
  [[ "$(<"$homebrew_root/brew.log")" == $'brew install git\nbrew install zsh' ]] || fail 'bootstrap did not install Git before Zsh'
  if grep -q '^Symbolic links ' "$output"; then
    fail 'bootstrap exposed generic core success messages'
  fi
  pass 'bootstrap configures and validates Git before Zsh'
}

test_bootstrap_git_failure_skips_zsh() {
  local home
  local output="$TEST_ROOT/bootstrap-git-failure-output"
  local homebrew_root="$TEST_ROOT/bootstrap-git-failure-homebrew"
  local homebrew_bin="$homebrew_root/bin"
  home="$(new_home bootstrap-git-failure)"
  mkdir -p "$homebrew_bin"
  cp "$FIXTURE_BIN/apt-get" "$FIXTURE_BIN/curl" "$FIXTURE_BIN/sudo" "$homebrew_bin"
  chmod +x "$homebrew_bin/apt-get" "$homebrew_bin/curl" "$homebrew_bin/sudo"

  if HOME="$home" \
    PATH="$homebrew_bin:$homebrew_root/prefix/bin:$PATH" \
    HOMEBREW_TEST_PREFIX="$homebrew_root/prefix" \
    HOMEBREW_TEST_CURL_LOG="$homebrew_root/curl.log" \
    HOMEBREW_TEST_INSTALL_LOG="$homebrew_root/install.log" \
    HOMEBREW_TEST_INSTALLER="$ROOT_DIR/tests/fixtures/homebrew-installer.sh" \
    HOMEBREW_TEST_APT_LOG="$homebrew_root/apt.log" \
    HOMEBREW_TEST_BREW_LOG="$homebrew_root/brew.log" \
    HOMEBREW_TEST_INSTALL_FAIL=git \
    DEV_WORKSTATION_BREW_PATH="$homebrew_root/prefix/bin/brew" \
    bash "$BOOTSTRAP" ubuntu >"$output" 2>&1; then
    fail 'bootstrap succeeded after Git installation failure'
  fi

  [[ "$(<"$homebrew_root/brew.log")" == 'brew install git' ]] || fail 'Git failure did not stop before Zsh installation'
  [[ ! -e "$home/.gitconfig" && ! -L "$home/.gitconfig" ]] || fail 'failed Git install configured Git'
  [[ ! -e "$home/.zshrc" && ! -L "$home/.zshrc" ]] || fail 'Git failure reached Zsh'
  pass 'Git failure prevents any Zsh phase'
}

test_zsh_failure_keeps_validated_git() {
  local home
  local output="$TEST_ROOT/zsh-failure-output"
  home="$(new_home module-boundary)"
  setup_homebrew module-boundary-brew
  install_formula_fixture module-boundary-brew git

  HOME="$home" DEV_WORKSTATION_PACKAGE_PROVIDER=brew \
    with_homebrew module-boundary-brew bash "$GIT_MODULE" all >/dev/null || fail 'Git setup failed'
  if HOME="$home" \
    PATH="$FIXTURE_BIN:$PATH" \
    SYMLINK_TEST_LN_MODE='fail-first' \
    SYMLINK_TEST_LN_COUNT_FILE="$TEST_ROOT/zsh-failure-count" \
    SYMLINK_TEST_REAL_LN="$REAL_LN" \
    SYMLINK_TEST_REAL_MV="$REAL_MV" \
    SYMLINK_TEST_REAL_RM="$REAL_RM" \
    SYMLINK_TEST_RM_FAIL=0 \
    bash "$ZSH_MODULE" configure >"$output" 2>&1; then
    fail 'controlled Zsh failure unexpectedly succeeded'
  fi

  assert_link "$home/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
  assert_link "$home/.gitignore_global" "$ROOT_DIR/dotfiles/git/.gitignore_global"
  [[ ! -e "$home/.zshrc" && ! -L "$home/.zshrc" ]] || fail 'failed Zsh module left .zshrc behind'
  pass 'Zsh failure does not undo the validated Git module'
}

printf '1..13\n'
test_git_module_owns_only_git
test_zsh_module_owns_only_zsh
test_zsh_install_is_idempotent_when_present
test_zsh_install_uses_homebrew_when_absent
test_zsh_install_fails_without_brew_provider
test_zsh_validation_checks_syntax
test_git_install_uses_homebrew_when_absent
test_git_install_fails_without_brew_provider
test_git_configuration_is_idempotent_and_preserves_existing_files
test_git_failure_rolls_back_both_targets
test_bootstrap_configures_all_assets
test_bootstrap_git_failure_skips_zsh
test_zsh_failure_keeps_validated_git
