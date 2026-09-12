#!/usr/bin/env bash
# Run as your normal user, never with sudo. SDKMAN manages per-user tools.
set -e

usage() {
  printf 'Usage: bash omarchy/java/setup.sh [--java <sdkman-id>] [--maven <version>]\n'
  printf 'Without version flags, preserve existing defaults or install SDKMAN defaults.\n'
}

java_version=
maven_version=
while (( $# )); do
  case $1 in
    --java|--maven)
      if [[ $# -lt 2 || ! $2 =~ ^[[:alnum:]][[:alnum:]._-]*$ ]]; then
        usage >&2
        exit 1
      fi
      case $1 in
        --java) java_version=$2 ;;
        --maven) maven_version=$2 ;;
      esac
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

if (( EUID == 0 )); then
  printf 'Run this script as your normal user, without sudo.\n' >&2
  exit 1
fi

missing=()
for tool in curl zip unzip; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if (( ${#missing[@]} )); then
  printf 'Install missing dependencies first: omarchy pkg add'
  printf ' %s' "${missing[@]}"
  printf '\n'
  exit 1
fi

export SDKMAN_DIR=${SDKMAN_DIR:-$HOME/.sdkman}
if [[ ! -s $SDKMAN_DIR/bin/sdkman-init.sh ]]; then
  if [[ -e $SDKMAN_DIR || -L $SDKMAN_DIR ]]; then
    printf 'Incomplete SDKMAN installation at %s; inspect it before retrying.\n' "$SDKMAN_DIR" >&2
    exit 1
  fi
  installer=$(mktemp)
  trap 'rm -f -- "$installer"' EXIT
  # Do not let the upstream installer append to repository-managed shell loaders.
  curl --fail --silent --show-error --location 'https://get.sdkman.io?rcupdate=false' -o "$installer"
  bash "$installer"
fi

# SDKMAN is shell code, not guaranteed to support errexit/nounset. Check its
# results explicitly instead of imposing strict shell options on upstream code.
set +e
source "$SDKMAN_DIR/bin/sdkman-init.sh" || exit 1

install_candidate() {
  local candidate=$1 version=$2 executable=$3
  local current="$SDKMAN_DIR/candidates/$1/current"
  if [[ -z $version && -x $current/bin/$executable ]]; then
    printf '%s already configured: %s\n' "$candidate" "$(readlink -f -- "$current")"
    return 0
  fi
  if [[ -n $version ]]; then
    if [[ ! -x $SDKMAN_DIR/candidates/$candidate/$version/bin/$executable ]]; then
      sdk install "$candidate" "$version" || return 1
    fi
    if [[ $(readlink -f -- "$current") != "$SDKMAN_DIR/candidates/$candidate/$version" ]]; then
      sdk default "$candidate" "$version" || return 1
    fi
  else
    sdk install "$candidate" || return 1
  fi
  [[ -x $current/bin/$executable ]]
}

install_candidate java "$java_version" java || exit 1
install_candidate maven "$maven_version" mvn || exit 1

# Validate the selected SDKMAN tools, not an inherited mise/system executable.
export JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
export PATH="$JAVA_HOME/bin:$SDKMAN_DIR/candidates/maven/current/bin:$PATH"
java -version || exit 1
javac -version || exit 1
mvn -version || exit 1
printf '\nSetup complete. Open a fresh repository-configured Bash/Zsh terminal.\n'
printf 'For this shell: source "$SDKMAN_DIR/bin/sdkman-init.sh" (set SDKMAN_DIR first if custom).\n'
