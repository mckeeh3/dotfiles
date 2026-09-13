#!/usr/bin/env bash
set -euo pipefail

apply=false
case "${1:-}" in
  '') ;;
  --apply) apply=true ;;
  --help|-h)
    printf 'Usage: bash omarchy/packages/setup.sh [--apply]\nPreview missing packages by default; --apply installs them through Omarchy.\n'
    exit 0
    ;;
  *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
esac
if (( $# > 1 )); then
  printf 'Expected at most one argument.\n' >&2
  exit 1
fi

command -v pacman >/dev/null || { printf 'pacman is required.\n' >&2; exit 1; }
dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=()
aur=()
# Validate both lists before attempting any installation. Never evaluate list contents.
for source in repo aur; do
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%%#*}
    read -r package extra <<< "$line"
    [[ -n "$package" ]] || continue
    if [[ -n "$extra" || ! "$package" =~ ^[a-z0-9@_+][a-z0-9@._+-]*$ ]]; then
      printf 'Invalid package entry in %s.txt: %s\n' "$source" "$line" >&2
      exit 1
    fi
    if pacman -Q "$package" >/dev/null 2>&1; then
      printf 'Installed: %s\n' "$package"
    elif [[ "$source" == repo ]]; then
      repo+=("$package")
    else
      aur+=("$package")
    fi
  done < "$dir/$source.txt"
done

if (( ${#repo[@]} + ${#aur[@]} == 0 )); then
  printf 'All listed packages are installed.\n'
  exit 0
fi
for source in repo aur; do
  declare -n packages="$source"
  if (( ${#packages[@]} )); then
    printf 'Missing (%s):' "$source"
    printf ' %s' "${packages[@]}"
    printf '\n'
  fi
  unset -n packages
done
if ! "$apply"; then
  printf 'Review the lists, then run with --apply in a visible terminal to install.\n'
  exit 0
fi
if (( EUID == 0 )); then
  printf 'Run as your normal user, not root; Omarchy handles privilege elevation.\n' >&2
  exit 1
fi
command -v omarchy >/dev/null || { printf 'omarchy is required.\n' >&2; exit 1; }
if (( ${#repo[@]} )); then
  omarchy pkg add "${repo[@]}"
fi
if (( ${#aur[@]} )); then
  omarchy pkg aur add "${aur[@]}"
fi
for package in "${repo[@]}" "${aur[@]}"; do
  pacman -Q "$package" >/dev/null || { printf 'Package not installed: %s\n' "$package" >&2; exit 1; }
done
printf 'Package setup complete.\n'
