#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
unset ZDOTDIR
mkdir -p "$HOME" "$XDG_CONFIG_HOME/ghostty"
printf '# Keep Bash\n' > "$HOME/.bashrc"
printf '# Keep prompt\n' > "$XDG_CONFIG_HOME/starship.toml"
printf 'font-size = 12\n' > "$XDG_CONFIG_HOME/ghostty/config"

# Exercise loader quoting with a repository path containing spaces.
copy="$tmp/repo with spaces"
mkdir -p "$copy/omarchy"
cp "$repo/omarchy-zsh-setup.sh" "$copy/"
cp -r "$repo/omarchy/zsh" "$copy/omarchy/"
cp "$repo/omarchy/ghostty-zsh.conf" "$copy/omarchy/"
installer="$copy/omarchy-zsh-setup.sh"
bash "$installer" --ghostty >/dev/null
zsh -n "$HOME/.zshrc"
ghostty +validate-config --config-file="$XDG_CONFIG_HOME/ghostty/config"
printf '# Keep Bash\n' | cmp - "$HOME/.bashrc"
printf '# Keep prompt\n' | cmp - "$XDG_CONFIG_HOME/starship.toml"
grep -Fxq 'font-size = 12' "$XDG_CONFIG_HOME/ghostty/config"
cp "$XDG_CONFIG_HOME/ghostty/config" "$tmp/installed-ghostty"
bash "$installer" --ghostty >/dev/null
cmp "$XDG_CONFIG_HOME/ghostty/config" "$tmp/installed-ghostty"
shopt -s nullglob
backups=("$XDG_CONFIG_HOME/ghostty"/config.bak.*)
(( ${#backups[@]} == 1 ))
printf 'font-size = 12\n' | cmp - "${backups[0]}/config"

printf '# Existing Zsh\n' > "$HOME/.zshrc"
if bash "$installer" --ghostty >/dev/null 2>&1; then
  printf 'FAIL: replaced existing Zsh without consent\n' >&2; exit 1
fi
cmp "$XDG_CONFIG_HOME/ghostty/config" "$tmp/installed-ghostty"
bash "$installer" --replace-zshrc >/dev/null
backups=("$HOME"/.zshrc.bak.*)
(( ${#backups[@]} == 1 ))
printf '# Existing Zsh\n' | cmp - "${backups[0]}/.zshrc"

rm "$HOME/.zshrc"
printf '# Symlink target\n' > "$tmp/original"
ln -s "$tmp/original" "$HOME/.zshrc"
bash "$installer" --replace-zshrc >/dev/null
[[ ! -L $HOME/.zshrc ]]
printf '# Symlink target\n' | cmp - "$tmp/original"
if ZDOTDIR="$tmp/custom" bash "$installer" >/dev/null 2>&1; then
  printf 'FAIL: accepted custom ZDOTDIR\n' >&2; exit 1
fi
printf 'Zsh installer tests passed.\n'
