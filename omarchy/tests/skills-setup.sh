#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/repo/omarchy/skills" "$tmp/home"
cp "$repo/omarchy/skills/setup.sh" "$tmp/repo/omarchy/skills/"
cp -R "$repo/omarchy/skills/unslop" "$tmp/repo/omarchy/skills/"
mkdir -p "$tmp/repo/omarchy/skills/second"
printf '%s\n' '---' 'name: second' 'description: Test skill' '---' > "$tmp/repo/omarchy/skills/second/SKILL.md"
export HOME="$tmp/home" PI_CODING_AGENT_DIR="$tmp/pi" CODEX_HOME="$tmp/codex"
script="$tmp/repo/omarchy/skills/setup.sh"

bash -n "$script"
if bash "$script" --unknown >/dev/null 2>&1; then echo 'Accepted unknown option' >&2; exit 1; fi
bash "$script" > "$tmp/preview"
[[ $(grep -c '^Would link:' "$tmp/preview") == 6 ]]
[[ ! -e "$PI_CODING_AGENT_DIR" && ! -e "$CODEX_HOME" && ! -e "$HOME/.claude" ]]

# A conflict anywhere must stop the run before writing even the first link.
mkdir -p "$HOME/.claude/skills/second"
printf 'keep\n' > "$HOME/.claude/skills/second/SKILL.md"
if bash "$script" --apply > "$tmp/output" 2>&1; then echo 'Ignored conflict' >&2; exit 1; fi
[[ ! -e "$PI_CODING_AGENT_DIR" && ! -e "$CODEX_HOME" ]]
[[ $(< "$HOME/.claude/skills/second/SKILL.md") == keep ]]
rm -r -- "$HOME/.claude/skills/second"

bash "$script" --apply > "$tmp/output"
for dir in "$PI_CODING_AGENT_DIR/skills" "$CODEX_HOME/skills" "$HOME/.claude/skills"; do
  for name in unslop second; do
    [[ -L "$dir/$name" ]]
    [[ $(readlink -- "$dir/$name") == "$tmp/repo/omarchy/skills/$name" ]]
    [[ -f "$dir/$name/SKILL.md" ]]
  done
done
bash "$script" --apply > "$tmp/output"
grep -q 'No new skill links needed' "$tmp/output"
[[ $(grep -c '^Already linked:' "$tmp/output") == 6 ]]

# A dangling symlink is not safe to overwrite either.
rm -- "$HOME/.claude/skills/second"
ln -s -- "$tmp/gone" "$HOME/.claude/skills/second"
if bash "$script" --apply > "$tmp/output" 2>&1; then echo 'Overwrote dangling link' >&2; exit 1; fi
[[ $(readlink -- "$HOME/.claude/skills/second") == "$tmp/gone" ]]
printf 'Skill setup tests passed.\n'
