#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: bash omarchy-zsh-setup.sh [--replace-zshrc] [--ghostty]' \
    'Install the separate Omarchy Zsh profile; optionally enable it in Ghostty.' \
    'Existing differing .zshrc files require --replace-zshrc and are backed up.' \
    'Bash, the login shell, Starship config, and history files are never changed.' \
    'No packages are installed. Custom ZDOTDIR setups must be configured manually.'
}
replace=0
ghostty=0
while (( $# )); do
  case $1 in
    --replace-zshrc) replace=1 ;;
    --ghostty) ghostty=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
  shift
done
[[ -z ${ZDOTDIR:-} || $ZDOTDIR == "$HOME" ]] || { printf 'Custom ZDOTDIR; refusing automatic installation.\n' >&2; exit 1; }
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
profile=$repo/omarchy/zsh/zshrc
config=${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config
include=$repo/omarchy/ghostty-zsh.conf
target=$HOME/.zshrc
command -v zsh >/dev/null
zsh -n "$profile"
zsh -n "$repo/omarchy/zsh/aliases.zsh"
for file in "$target"; do
  [[ ! -d $file && ( ! -e $file || -f $file ) ]] || { printf 'Not a regular file: %s\n' "$file" >&2; exit 1; }
done
if (( ghostty )); then
  command -v ghostty >/dev/null
  [[ -r $include ]] || exit 1
  # Ghostty quoted config values cannot represent arbitrary repository names.
  [[ $include != *\"* && $include != *\\* && $include != *$'\n'* ]] || exit 1
  [[ ! -L $config && ( ! -e $config || -f $config ) ]] || {
    printf 'Ghostty config is a symlink or special file; configure it manually.\n' >&2; exit 1;
  }
fi

tmp=$(mktemp "$HOME/.zshrc.dotfiles.XXXXXXXX")
trap 'rm -f -- "$tmp"' EXIT
{
  printf '# Omarchy Zsh loader managed by dotfiles/omarchy-zsh-setup.sh.\n'
  printf '# Local overrides: ~/.config/dotfiles/zsh.local.zsh\n'
  printf 'source %q\n' "$profile"
} > "$tmp"
zsh -n "$tmp"
if cmp -s -- "$tmp" "$target"; then
  printf 'Already installed: %s\n' "$target"
else
  if [[ -e $target || -L $target ]]; then
    (( replace )) || { printf 'Existing .zshrc differs; use --replace-zshrc after reviewing it.\n' >&2; exit 1; }
    backup=$(mktemp -d "$HOME/.zshrc.bak.XXXXXXXX")
    cp -a -- "$target" "$backup/.zshrc"
    printf 'Backup: %s/.zshrc\n' "$backup"
  fi
  mv -fT -- "$tmp" "$target"
  printf 'Installed: %s\n' "$target"
fi

if (( ghostty )); then
  line="config-file = \"$include\""
  if [[ -f $config ]] && grep -Fxq -- "$line" "$config"; then
    printf 'Ghostty Zsh include already installed.\n'
  else
    mkdir -p -- "$(dirname -- "$config")"
    if [[ -e $config ]]; then
      backup=$(mktemp -d "${config}.bak.XXXXXXXX")
      cp -a -- "$config" "$backup/config"
      printf 'Backup: %s/config\n' "$backup"
    fi
    printf '\n# Dotfiles: use Zsh in Ghostty, keep Bash as the login shell.\n%s\n' "$line" >> "$config"
    printf 'Enabled Zsh in: %s\n' "$config"
  fi
fi
printf 'Open a new Zsh terminal. The login shell and Bash configuration are unchanged.\n'
