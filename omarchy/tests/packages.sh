#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/packages"
cp "$repo/omarchy/packages/"* "$tmp/packages/"
export STATE="$tmp/state" CALLS="$tmp/calls"
: > "$STATE"
: > "$CALLS"
cat > "$tmp/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == -Q ]] || exit 1
grep -Fxq -- "$2" "$STATE"
MOCK
cat > "$tmp/bin/omarchy" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
[[ "${FAIL_INSTALL:-0}" == 0 ]] || exit 1
[[ "$1" == pkg ]] || exit 1
shift
[[ "$1" != aur ]] || shift
[[ "$1" == add ]] || exit 1
shift
printf '%s\n' "$@" >> "$STATE"
MOCK
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
script="$tmp/packages/setup.sh"
bash "$script" > "$tmp/output"
grep -q 'Missing (repo): localsend' "$tmp/output"
[[ ! -s "$CALLS" ]]
printf 'test-aur # Example\n' >> "$tmp/packages/aur.txt"
if (( EUID != 0 )); then
  bash "$script" --apply > "$tmp/output"
  grep -Fxq 'pkg add localsend' "$CALLS"
  grep -Fxq 'pkg aur add test-aur' "$CALLS"
  cp "$CALLS" "$tmp/first-calls"
  bash "$script" --apply > "$tmp/output"
  cmp "$CALLS" "$tmp/first-calls"
  grep -q 'All listed packages are installed' "$tmp/output"
  : > "$STATE"
  if FAIL_INSTALL=1 bash "$script" --apply >/dev/null 2>&1; then
    printf 'Ignored installation failure\n' >&2; exit 1
  fi
else
  printf 'Skipping apply tests as root.\n'
fi
printf '%s\n' '--bad-option' >> "$tmp/packages/aur.txt"
cp "$CALLS" "$tmp/before-invalid"
if bash "$script" --apply >/dev/null 2>&1; then
  printf 'Accepted invalid package entry\n' >&2; exit 1
fi
cmp "$CALLS" "$tmp/before-invalid"
if bash "$script" --unknown >/dev/null 2>&1; then
  printf 'Accepted unknown flag\n' >&2; exit 1
fi
printf 'Package setup tests passed.\n'
