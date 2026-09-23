#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: bash omarchy/skills/setup.sh [--apply]\nPreview links by default; --apply links all repository skills for Pi, Codex, and Claude.\n'
}

case "${1:-}" in
  '') apply=0 ;;
  --apply) apply=1 ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 1 ;;
esac
(( $# <= 1 )) || { usage >&2; exit 1; }

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
pi_dir=${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}
# Resolve relative overrides the same way regardless of where the installer is run.
[[ "$pi_dir" = /* ]] || { printf 'PI_CODING_AGENT_DIR must be an absolute path.\n' >&2; exit 1; }
destinations=("$pi_dir/skills" "${CODEX_HOME:-$HOME/.codex}/skills" "$HOME/.claude/skills")
for dir in "${destinations[@]}"; do
  [[ "$dir" = /* ]] || { printf 'Skill destinations must be absolute paths: %s\n' "$dir" >&2; exit 1; }
done

shopt -s nullglob
skills=("$root"/*)
links=()
sources=()
for source in "${skills[@]}"; do
  [[ -d "$source" && ! -L "$source" ]] || continue
  name=${source##*/}
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ && ${#name} -le 64 && -f "$source/SKILL.md" ]] || {
    printf 'Invalid skill directory (expected name and SKILL.md): %s\n' "$source" >&2
    exit 1
  }
  for dir in "${destinations[@]}"; do
    target="$dir/$name"
    if [[ -L "$target" && $(readlink -- "$target") == "$source" ]]; then
      printf 'Already linked: %s\n' "$target"
    elif [[ -e "$target" || -L "$target" ]]; then
      printf 'Conflict: %s exists; inspect it and move it aside yourself.\n' "$target" >&2
      exit 1
    else
      links+=("$target")
      sources+=("$source")
    fi
  done
done

if (( ${#links[@]} == 0 )); then
  printf 'No new skill links needed.\n'
  exit 0
fi
for i in "${!links[@]}"; do
  if (( apply )); then
    mkdir -p -- "${links[i]%/*}"
    ln -sT -- "${sources[i]}" "${links[i]}"
    printf 'Linked: %s -> %s\n' "${links[i]}" "${sources[i]}"
  else
    printf 'Would link: %s -> %s\n' "${links[i]}" "${sources[i]}"
  fi
done
if (( ! apply )); then
  printf 'Review the skills, then run with --apply to install.\n'
fi
