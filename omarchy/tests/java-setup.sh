#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIR"' EXIT
export HOME="$TEST_DIR/home with spaces"
export SDKMAN_DIR="$HOME/.sdkman"
export CALLS="$TEST_DIR/calls"
export MOCK_INIT="$TEST_DIR/sdkman-init.sh"
mkdir -p "$HOME" "$TEST_DIR/bin"
export PATH="$TEST_DIR/bin:$PATH"
: > "$CALLS"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Never contact upstream or install packages in tests.
cat > "$TEST_DIR/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf 'download\n' >> "$CALLS"
[[ $* == *'https://get.sdkman.io?rcupdate=false'* ]] || exit 1
while (( $# )); do
  if [[ $1 == -o ]]; then
    cp "$MOCK_INIT.installer" "$2"
    exit
  fi
  shift
done
exit 1
MOCK
cat > "$MOCK_INIT.installer" <<'MOCK'
mkdir -p "$SDKMAN_DIR/bin"
cp "$MOCK_INIT" "$SDKMAN_DIR/bin/sdkman-init.sh"
MOCK
cat > "$MOCK_INIT" <<'MOCK'
sdk() {
  printf '%s\n' "$*" >> "$CALLS"
  [[ ${MOCK_FAIL:-0} == 0 ]] || return 1
  local action=$1 candidate=$2 version=${3:-recommended} executable
  case $action in
    install)
      mkdir -p "$SDKMAN_DIR/candidates/$candidate/$version/bin"
      for executable in java javac mvn; do
        printf '#!/bin/sh\nexit 0\n' > "$SDKMAN_DIR/candidates/$candidate/$version/bin/$executable"
        chmod +x "$SDKMAN_DIR/candidates/$candidate/$version/bin/$executable"
      done
      ;;
    default) ;;
    *) return 1 ;;
  esac
  ln -sfn "$version" "$SDKMAN_DIR/candidates/$candidate/current"
}
MOCK
chmod +x "$TEST_DIR/bin/curl"
# Dependency checks must not depend on whether zip is installed on the test host.
for tool in zip unzip; do
  printf '#!/bin/sh\nexit 0\n' > "$TEST_DIR/bin/$tool"
  chmod +x "$TEST_DIR/bin/$tool"
done

installer="$REPO_DIR/omarchy/java/setup.sh"
bash "$installer" --help >/dev/null
if bash "$installer" --java >/dev/null 2>&1; then fail 'accepted missing version'; fi
if bash "$installer" --unknown >/dev/null 2>&1; then fail 'accepted unknown option'; fi
bash "$installer" >/dev/null 2>&1
[[ $(wc -l < "$CALLS") == 3 ]] || fail 'expected bootstrap and two installs'
[[ ! -e $HOME/.bashrc && ! -e $HOME/.zshrc ]] || fail 'created shell loaders'
cp "$CALLS" "$TEST_DIR/first-calls"
bash "$installer" >/dev/null 2>&1
cmp "$CALLS" "$TEST_DIR/first-calls" || fail 'rerun installed tools'

bash "$installer" --java 21-test --maven 3-test >/dev/null 2>&1
[[ $(readlink "$SDKMAN_DIR/candidates/java/current") == 21-test ]] || fail 'wrong Java default'
[[ $(readlink "$SDKMAN_DIR/candidates/maven/current") == 3-test ]] || fail 'wrong Maven default'
cp "$CALLS" "$TEST_DIR/pinned-calls"
bash "$installer" --java 21-test --maven 3-test >/dev/null 2>&1
cmp "$CALLS" "$TEST_DIR/pinned-calls" || fail 'pinned rerun mutated defaults'
bash "$installer" --java recommended >/dev/null 2>&1
[[ $(tail -1 "$CALLS") == 'default java recommended' ]] || fail 'did not reuse installed JDK'
[[ $(readlink "$SDKMAN_DIR/candidates/maven/current") == 3-test ]] || fail 'changed unrelated Maven default'
if MOCK_FAIL=1 bash "$installer" --maven broken >/dev/null 2>&1; then fail 'ignored SDKMAN failure'; fi

export SDKMAN_DIR="$HOME/partial"
mkdir -p "$SDKMAN_DIR"
printf 'preserve\n' > "$SDKMAN_DIR/marker"
cp "$CALLS" "$TEST_DIR/before-partial"
if bash "$installer" >/dev/null 2>&1; then fail 'accepted incomplete SDKMAN'; fi
cmp "$CALLS" "$TEST_DIR/before-partial" || fail 'downloaded over partial install'
[[ $(< "$SDKMAN_DIR/marker") == preserve ]] || fail 'modified partial install'
printf 'All Java/Maven setup tests passed.\n'
