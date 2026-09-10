#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# No live dotfiles, secrets, history, or package manager changes.
export HOME="$TEST_DIR/home"
export XDG_CONFIG_HOME="$HOME/.config"
export OMARCHY_PATH="$TEST_DIR/omarchy"
mkdir -p "$HOME" "$OMARCHY_PATH/default/bash"
printf '# Mock defaults for installer checks only.\n' > "$OMARCHY_PATH/default/bash/rc"

# Include spaces and shell metacharacters to test generated source-line quoting.
COPY_DIR="$TEST_DIR/repo with spaces \$quote'"
mkdir -p "$COPY_DIR/omarchy"
cp "$REPO_DIR/omarchy-setup.sh" "$REPO_DIR/ssh2" "$COPY_DIR/"
cp "$REPO_DIR/omarchy/starship.toml" "$COPY_DIR/omarchy/"
cp -r "$REPO_DIR/omarchy/bash" "$COPY_DIR/omarchy/"
cp -r "$REPO_DIR/omarchy/starship-prompts" "$COPY_DIR/omarchy/"
INSTALLER="$COPY_DIR/omarchy-setup.sh"

bash "$INSTALLER" >/dev/null
bash -n "$HOME/.bashrc"
[[ -L $HOME/.local/bin/ssh2 && $(readlink "$HOME/.local/bin/ssh2") == "$COPY_DIR/ssh2" ]] || fail 'missing ssh2 link'
"$HOME/.local/bin/ssh2" --help >/dev/null
cmp "$HOME/.config/starship.toml" "$REPO_DIR/omarchy/starship.toml"
# Non-interactive loading must not enable aliases, history hooks, or ble.sh.
bash --noprofile --norc -c 'source "$HOME/.bashrc"; ! declare -F _dotfiles_history_sync >/dev/null'
cp "$HOME/.bashrc" "$TEST_DIR/installed"
cp "$HOME/.config/starship.toml" "$TEST_DIR/installed-starship"
bash "$INSTALLER" >/dev/null
cmp "$HOME/.bashrc" "$TEST_DIR/installed"
cmp "$HOME/.config/starship.toml" "$TEST_DIR/installed-starship"
shopt -s nullglob
backups=("$HOME"/.bashrc.bak.*)
(( ${#backups[@]} == 0 )) || fail 'rerun created backups'
starship_backups=("$HOME/.config"/starship.toml.bak.*)
(( ${#starship_backups[@]} == 0 )) || fail 'rerun created starship backups'

# Never overwrite an existing command, dangling link, or directory.
for kind in file link directory; do
  rm "$HOME/.local/bin/ssh2"
  case "$kind" in
    file) printf 'personal command\n' > "$HOME/.local/bin/ssh2" ;;
    link) ln -s "$TEST_DIR/missing-ssh2" "$HOME/.local/bin/ssh2" ;;
    directory) mkdir "$HOME/.local/bin/ssh2" ;;
  esac
  if bash "$INSTALLER" >/dev/null 2>&1; then fail "replaced ssh2 $kind"; fi
  case "$kind" in
    file) [[ $(< "$HOME/.local/bin/ssh2") == 'personal command' ]] || fail 'modified command'; rm "$HOME/.local/bin/ssh2" ;;
    link) [[ $(readlink "$HOME/.local/bin/ssh2") == "$TEST_DIR/missing-ssh2" ]] || fail 'modified link'; rm "$HOME/.local/bin/ssh2" ;;
    directory) rmdir "$HOME/.local/bin/ssh2" ;;
  esac
  bash "$INSTALLER" >/dev/null
done

printf '# Existing Starship settings\n' > "$HOME/.config/starship.toml"
cp "$HOME/.config/starship.toml" "$TEST_DIR/original-starship"
if bash "$INSTALLER" >/dev/null 2>&1; then
  fail 'replaced existing Starship config without consent'
fi
cmp "$HOME/.config/starship.toml" "$TEST_DIR/original-starship"
bash "$INSTALLER" --replace-starship >/dev/null
starship_backups=("$HOME/.config"/starship.toml.bak.*)
(( ${#starship_backups[@]} == 1 )) || fail 'expected one starship backup'
cmp "${starship_backups[0]}/starship.toml" "$TEST_DIR/original-starship"
cmp "$HOME/.config/starship.toml" "$REPO_DIR/omarchy/starship.toml"

printf '# Existing personal settings\nalias personal=true\n' > "$HOME/.bashrc"
cp "$HOME/.bashrc" "$TEST_DIR/original"
if bash "$INSTALLER" >/dev/null 2>&1; then
  fail 'replaced existing config without consent'
fi
cmp "$HOME/.bashrc" "$TEST_DIR/original"
bash "$INSTALLER" --replace-bashrc >/dev/null
backups=("$HOME"/.bashrc.bak.*)
(( ${#backups[@]} == 1 )) || fail 'expected one backup'
cmp "${backups[0]}/.bashrc" "$TEST_DIR/original"
bash "$INSTALLER" --replace-bashrc >/dev/null
backups=("$HOME"/.bashrc.bak.*)
(( ${#backups[@]} == 1 )) || fail 'explicit rerun created another backup'

# Replacing symlinks must not write through to their source files.
rm "$HOME/.bashrc"
ln -s "$TEST_DIR/original" "$HOME/.bashrc"
bash "$INSTALLER" --replace-bashrc >/dev/null
[[ ! -L $HOME/.bashrc ]] || fail 'symlink was not replaced'
printf '# Existing personal settings\nalias personal=true\n' | cmp - "$TEST_DIR/original"
backups=("$HOME"/.bashrc.bak.*)
links=0
for backup in "${backups[@]}"; do
  if [[ -L $backup/.bashrc ]]; then links=$((links + 1)); fi
done
(( links == 1 )) || fail 'original symlink was not preserved'

rm "$HOME/.bashrc"
ln -s "$TEST_DIR/nonexistent" "$HOME/.bashrc"
if bash "$INSTALLER" >/dev/null 2>&1; then fail 'replaced dangling symlink without consent'; fi
bash "$INSTALLER" --replace-bashrc >/dev/null
[[ ! -e $TEST_DIR/nonexistent ]] || fail 'wrote through dangling symlink'
rm "$HOME/.bashrc"
mkdir "$HOME/.bashrc"
if bash "$INSTALLER" --replace-bashrc >/dev/null 2>&1; then fail 'replaced directory'; fi
if bash "$INSTALLER" --unknown >/dev/null 2>&1; then fail 'accepted unknown flag'; fi
if OMARCHY_PATH="$TEST_DIR/missing" bash "$INSTALLER" >/dev/null 2>&1; then fail 'accepted missing Omarchy'; fi

# Test hooks with both scalar and array PROMPT_COMMAND, without live integrations.
for form in scalar array unset; do
  (
    unset PROMPT_COMMAND
    HISTFILE="$TEST_DIR/history-$form"
    touch "$HISTFILE"
    history -s 'dotfiles-history-test'
    case "$form" in
      scalar) PROMPT_COMMAND='printf scalar' ;;
      array) PROMPT_COMMAND=('printf first' 'printf second') ;;
    esac
    source "$REPO_DIR/omarchy/bash/after.sh"
    [[ ${PROMPT_COMMAND[0]} == _dotfiles_history_sync ]] || fail 'missing history hook'
    case "$form" in
      scalar) [[ ${PROMPT_COMMAND[1]} == 'printf scalar' ]] ;;
      array) [[ ${PROMPT_COMMAND[1]} == 'printf first' && ${PROMPT_COMMAND[2]} == 'printf second' ]] ;;
    esac
    count=${#PROMPT_COMMAND[@]}
    source "$REPO_DIR/omarchy/bash/after.sh"
    (( ${#PROMPT_COMMAND[@]} == count )) || fail 'duplicate prompt hook'
    if (exit 7); then :; else
      if _dotfiles_history_sync; then fail 'lost exit status'; else [[ $? == 7 ]]; fi
    fi
    command grep -q '^dotfiles-history-test$' "$HISTFILE" || fail 'history was not appended'
    shopt -q autocd histappend cmdhist lithist
    [[ $HISTSIZE == 100000 && $HISTFILESIZE == 200000 ]]
    starship-prompt easy-term >/dev/null
    cmp "$HOME/.config/starship.toml" "$REPO_DIR/omarchy/starship-prompts/easy-term.toml"
    [[ $(starship-prompt current) == easy-term ]]
    starship-prompt list | command grep -q '^  tokyo-night$'
    if starship-prompt does-not-exist >/dev/null 2>&1; then fail 'accepted unknown Starship prompt'; fi

    mkdir -p "$TEST_DIR/first dir" "$TEST_DIR/second dir"
    builtin cd "$TEST_DIR/first dir"
    pushd "$TEST_DIR/second dir" >/dev/null
    _dotfiles_cd_stack 1
    [[ $PWD == "$TEST_DIR/first dir" ]] || fail 'directory stack path with spaces'
    if _dotfiles_cd_stack 99 2>/dev/null; then fail 'accepted invalid stack index'; fi

    command git init -q -b main "$TEST_DIR/git-$form"
    builtin cd "$TEST_DIR/git-$form"
    command git -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m initial
    command git branch develop
    [[ $(git_current_branch) == main && $(git_main_branch) == main && $(git_develop_branch) == develop ]]
  )
done
printf 'All Omarchy Bash tests passed.\n'
