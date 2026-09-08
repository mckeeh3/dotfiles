#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: bash omarchy-setup.sh [--replace-bashrc] [--replace-starship]' \
    '' \
    'Install the Omarchy Bash profile and Starship prompt for the current user.' \
    'Existing differing files require their matching --replace-* flag and are backed up.' \
    'No packages are installed; no unrelated live configuration files are changed.'
}

replace_bashrc=0
replace_starship=0
while (( $# )); do
  case "$1" in
    --replace-bashrc) replace_bashrc=1 ;;
    --replace-starship) replace_starship=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROFILE_DIR="$SCRIPT_DIR/omarchy/bash"
STARSHIP_PROMPT_DIR="$SCRIPT_DIR/omarchy/starship-prompts"
STARSHIP_SOURCE="$SCRIPT_DIR/omarchy/starship.toml"
TARGET_FILE="${HOME:?HOME must be set}/.bashrc"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STARSHIP_TARGET="$CONFIG_HOME/starship.toml"

if [[ ! -r ${OMARCHY_PATH:-/usr/share/omarchy}/default/bash/rc ]]; then
  printf 'Omarchy Bash defaults not found. Run this on an Omarchy installation.\n' >&2
  exit 1
fi
for file in init.sh before.sh after.sh; do
  if [[ ! -r $PROFILE_DIR/$file ]]; then
    printf 'Missing profile file: %s\n' "$PROFILE_DIR/$file" >&2
    exit 1
  fi
  bash -n "$PROFILE_DIR/$file"
done
if [[ ! -r $STARSHIP_SOURCE ]]; then
  printf 'Missing Starship config: %s\n' "$STARSHIP_SOURCE" >&2
  exit 1
fi
if [[ ! -d $STARSHIP_PROMPT_DIR ]]; then
  printf 'Missing Starship prompt directory: %s\n' "$STARSHIP_PROMPT_DIR" >&2
  exit 1
fi
if command -v starship >/dev/null 2>&1; then
  STARSHIP_CONFIG="$STARSHIP_SOURCE" starship prompt >/dev/null
  for prompt in "$STARSHIP_PROMPT_DIR"/*.toml; do
    [[ -e $prompt ]] || continue
    STARSHIP_CONFIG="$prompt" starship prompt >/dev/null
  done
fi
if [[ -d $TARGET_FILE || ( -e $TARGET_FILE && ! -f $TARGET_FILE && ! -L $TARGET_FILE ) ]]; then
  printf 'Refusing to replace a directory or special file: %s\n' "$TARGET_FILE" >&2
  exit 1
fi

# %q supports repository paths containing spaces or shell metacharacters.
# The generated absolute path is local state, never written to the repository.
TEMP_FILE=$(mktemp "$HOME/.bashrc.dotfiles.XXXXXXXX")
trap 'rm -f -- "$TEMP_FILE"' EXIT
{
  printf '# Omarchy Bash profile managed by dotfiles/omarchy-setup.sh.\n'
  printf '# Local overrides: ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/bash.local.sh\n'
  printf 'source %q\n' "$PROFILE_DIR/init.sh"
} > "$TEMP_FILE"
bash -n "$TEMP_FILE"

if [[ -f $TARGET_FILE ]] && cmp -s -- "$TEMP_FILE" "$TARGET_FILE"; then
  printf 'Already installed: %s\n' "$TARGET_FILE"
else
  if [[ -e $TARGET_FILE || -L $TARGET_FILE ]]; then
    if (( ! replace_bashrc )); then
      printf 'Existing %s differs; nothing changed.\n' "$TARGET_FILE" >&2
      printf 'Review it first, then use --replace-bashrc to back it up and replace it.\n' >&2
      exit 1
    fi
    # Unique, private backup directory outside the repo; preserve symlinks as links.
    BACKUP_DIR=$(mktemp -d "$HOME/.bashrc.bak.XXXXXXXX")
    cp -a -- "$TARGET_FILE" "$BACKUP_DIR/.bashrc"
    printf 'Backed up existing .bashrc to %s/.bashrc\n' "$BACKUP_DIR"
  fi
  # Same-filesystem rename replaces a symlink rather than modifying its referent.
  mv -fT -- "$TEMP_FILE" "$TARGET_FILE"
  printf 'Installed: %s\n' "$TARGET_FILE"
fi

mkdir -p -- "$CONFIG_HOME"
if [[ -d $STARSHIP_TARGET || ( -e $STARSHIP_TARGET && ! -f $STARSHIP_TARGET && ! -L $STARSHIP_TARGET ) ]]; then
  printf 'Refusing to replace a directory or special file: %s\n' "$STARSHIP_TARGET" >&2
  exit 1
fi
if [[ -f $STARSHIP_TARGET ]] && cmp -s -- "$STARSHIP_SOURCE" "$STARSHIP_TARGET"; then
  printf 'Already installed: %s\n' "$STARSHIP_TARGET"
else
  if [[ -e $STARSHIP_TARGET || -L $STARSHIP_TARGET ]]; then
    if (( ! replace_starship )); then
      printf 'Existing %s differs; nothing changed.\n' "$STARSHIP_TARGET" >&2
      printf 'Review it first, then use --replace-starship to back it up and replace it.\n' >&2
      exit 1
    fi
    BACKUP_DIR=$(mktemp -d "$CONFIG_HOME/starship.toml.bak.XXXXXXXX")
    cp -a -- "$STARSHIP_TARGET" "$BACKUP_DIR/starship.toml"
    printf 'Backed up existing starship.toml to %s/starship.toml\n' "$BACKUP_DIR"
  fi
  TEMP_STARSHIP=$(mktemp "$CONFIG_HOME/starship.toml.dotfiles.XXXXXXXX")
  trap 'rm -f -- "$TEMP_FILE" "${TEMP_STARSHIP:-}"' EXIT
  cp -- "$STARSHIP_SOURCE" "$TEMP_STARSHIP"
  mv -fT -- "$TEMP_STARSHIP" "$STARSHIP_TARGET"
  printf 'Installed: %s\n' "$STARSHIP_TARGET"
fi

printf '\nDependency check (no packages will be installed):\n'
for tool in git fzf zoxide starship eza bat rg; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '  Missing command: %s (see omarchy/README.md)\n' "$tool"
  fi
done
if [[ ! -r /usr/share/bash-completion/bash_completion ]]; then
  printf '  Missing Bash completion: install bash-completion.\n'
fi
if [[ ! -r /usr/share/blesh/ble.sh ]]; then
  printf '  Missing ble.sh: install blesh-git from the AUR for suggestions/highlighting.\n'
fi
printf '\nOpen a fresh Bash terminal to apply. Keep this repository at its current path.\n'
