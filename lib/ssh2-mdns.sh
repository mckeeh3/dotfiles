# Sourced by ssh2; compatible with macOS Bash 3.2.

# Capture finite snapshots of streaming discovery tools without GNU timeout.
# Give the tool its own process group so timeout also stops any descendants.
# Job control is confined to this subshell, never the interactive picker.
ssh2_bounded() (
  set -m
  seconds=$1
  shift
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/ssh2-mdns.XXXXXXXX") || exit 1
  pid= watcher=
  cleanup_discovery() {
    if [[ -n $watcher ]]; then kill "$watcher" 2>/dev/null || true; wait "$watcher" 2>/dev/null || true; fi
    if [[ -n $pid ]]; then kill -KILL -- "-$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    rm -rf -- "$tmp"
  }
  trap cleanup_discovery EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  # Bash uses 512- or 1024-byte file-limit blocks depending on platform/mode:
  # either way the raw capture cannot exceed 64 KiB. This kernel limit also
  # bounds a writer that ignores SIGPIPE; discard stderr rather than capture it.
  (ulimit -c 0 && ulimit -f 64 && exec "$@") > "$tmp/output" 2>/dev/null &
  pid=$!
  (
    sleep "$seconds" &
    timer=$!
    trap 'kill "$timer" 2>/dev/null || true; wait "$timer" 2>/dev/null || true; exit' TERM INT
    wait "$timer"
    : > "$tmp/timeout"
    kill -KILL -- "-$pid" 2>/dev/null || true
  ) &
  watcher=$!
  status=0
  wait "$pid" 2>/dev/null || status=$?
  # Also stop descendants left behind by a command that exited early.
  kill -KILL -- "-$pid" 2>/dev/null || true
  pid=
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  watcher=
  # Never interpret a record cut off by the byte limit or timeout as complete.
  # Process at most 256 complete lines, even when the browser emits tiny lines.
  if [[ -s $tmp/output && -n $(tail -c 1 "$tmp/output") ]]; then
    sed '$d' "$tmp/output"
  else
    cat "$tmp/output"
  fi | awk 'NR <= 256 { print } NR == 257 { exit }'
  [[ ! -e $tmp/timeout ]] || exit 124
  exit "$status"
)

ssh2_mdns() (
  export LC_ALL=C
  deadline=$((SECONDS + 5))
  if [[ $(uname -s) == Darwin ]]; then
    if ! command -v dns-sd >/dev/null 2>&1; then
      echo 'mDNS unavailable (dns-sd missing); using configured targets.' >&2
      exit 0
    fi
    status=0
    output=$(ssh2_bounded 2 dns-sd -Z _ssh._tcp local.) || status=$?
    if (( status != 0 && status != 124 )); then
      echo 'Bonjour discovery failed; using available configured/discovered targets.' >&2
    fi
    # dns-sd -Z emits: instance._ssh._tcp. SRV 0 0 port host.local.
    # Never decode/evaluate service names or TXT data; use a validated host label.
    records=$(printf '%s\n' "$output" | awk '
      /_ssh\._tcp\.[[:space:]]+SRV[[:space:]]+0[[:space:]]+0[[:space:]]/ {
        sub(/^.*_ssh\._tcp\.[[:space:]]+SRV[[:space:]]+0[[:space:]]+0[[:space:]]+/, "")
        if ($1 ~ /^[0-9]+$/ && $1 > 0 && $1 <= 65535 &&
            length($2) <= 254 && $2 ~ /^[a-zA-Z0-9][a-zA-Z0-9.-]*[.]local[.]?$/) {
          host=tolower($2); sub(/[.]$/, "", host)
          if (!seen[host SUBSEP $1]++) {
            print host, $1
            if (++count == 64) exit
          }
        }
      }')
    while read -r host port; do
      [[ -n $host ]] || continue
      remaining=$((deadline - SECONDS))
      if (( remaining <= 0 )); then
        echo 'mDNS lookup budget exhausted; some targets may be missing.' >&2
        break
      fi
      resolve_status=0
      resolved=$(ssh2_bounded "$remaining" dscacheutil -q host -a name "$host") || resolve_status=$?
      if (( resolve_status != 0 )); then
        printf 'Bonjour address lookup failed/timed out for %s; using available targets.\n' "$host" >&2
      fi
      address=$(printf '%s\n' "$resolved" | awk '$1 == "ip_address:" { print $2; exit }')
      # Only resolved IPv4 endpoints are emitted, matching the Avahi backend.
      ssh2_mdns_record "$host" "$address" "$port"
    done <<< "$records"
  elif command -v avahi-browse >/dev/null 2>&1; then
    status=0
    output=$(ssh2_bounded 5 avahi-browse --resolve --terminate --parsable --no-db-lookup -4 _ssh._tcp) || status=$?
    if (( status == 124 )); then
      echo 'mDNS discovery timed out; using available configured/discovered targets.' >&2
    elif (( status != 0 )); then
      echo 'Avahi discovery failed; using available configured/discovered targets.' >&2
    fi
    # Avahi escapes delimiters in service names. Ignore names/TXT entirely.
    # Bound validation/merge work as well as the browser: at most 64 candidates.
    records=$(printf '%s\n' "$output" | awk -F ';' '
      $1 == "=" && $3 == "IPv4" && $5 == "_ssh._tcp" && $6 == "local" {
        if (!seen[tolower($7) SUBSEP $8 SUBSEP $9]++) {
          print
          if (++count == 64) exit
        }
      }')
    while IFS=';' read -r event interface protocol name type domain host address port txt; do
      [[ $event == = && $protocol == IPv4 && $type == _ssh._tcp && $domain == local ]] || continue
      ssh2_mdns_record "$host" "$address" "$port"
    done <<< "$records"
  else
    echo 'mDNS unavailable (avahi-browse missing); using configured targets. See omarchy/mdns/README.md.' >&2
  fi
)

ssh2_mdns_record() {
  local host=$1 address=$2 port=$3 a b c d octet
  (( ${#host} <= 254 )) || return 0
  [[ $host =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*\.local\.?$ ]] || return 0
  [[ $address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && $port =~ ^[0-9]{1,5}$ ]] || return 0
  (( 10#$port > 0 && 10#$port <= 65535 )) || return 0
  IFS=. read -r a b c d <<< "$address"
  for octet in "$a" "$b" "$c" "$d"; do
    (( 10#$octet <= 255 )) || return 0
  done
  host=$(printf '%s' "${host%.}" | tr '[:upper:]' '[:lower:]')
  printf '%s\t%d.%d.%d.%d\t%d\n' "$host" "$((10#$a))" "$((10#$b))" "$((10#$c))" "$((10#$d))" "$((10#$port))"
}
