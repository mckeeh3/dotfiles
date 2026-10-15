# Sourced by ssh2; compatible with macOS Bash 3.2.
# Only manual ssh2.config entries become persistent SSH aliases.
ssh2_sync_ssh_config() (
  set -e
  local ssh_dir=$HOME/.ssh config=$HOME/.ssh/config
  local tmp aliases i j label address normalized existing source_config

  if [[ ${#labels[@]} -eq 0 ]]; then
    echo 'No manual targets to sync from ssh2.config.' >&2
    exit 1
  fi
  for (( i=0; i<${#labels[@]}; i++ )); do
    label=${labels[$i]}
    address=${ips[$i]}
    if [[ ! $label =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ||
          ! $address =~ ^[a-zA-Z0-9][a-zA-Z0-9._:%-]*$ ]]; then
      printf 'Invalid SSH alias or address: %s %s\n' "$label" "$address" >&2
      exit 1
    fi
    normalized=$(printf '%s' "$label" | LC_ALL=C tr '[:upper:]' '[:lower:]')
    for (( j=0; j<i; j++ )); do
      existing=$(printf '%s' "${labels[$j]}" | LC_ALL=C tr '[:upper:]' '[:lower:]')
      if [[ $existing == "$normalized" ]]; then
        printf 'Duplicate SSH alias: %s\n' "$label" >&2
        exit 1
      fi
    done
  done

  if [[ -L $ssh_dir || ( -e $ssh_dir && ! -d $ssh_dir ) || -L $config ||
        ( -e $config && ! -f $config ) ]]; then
    echo 'SSH directory or config is a symlink or not a regular directory/file; review it first.' >&2
    exit 1
  fi
  [[ -d $ssh_dir ]] || mkdir -m 700 -- "$ssh_dir"
  tmp=$(mktemp "$ssh_dir/.ssh2-config.XXXXXXXX")
  aliases=
  trap 'rm -f -- "$tmp" ${aliases:+"$aliases"}' EXIT
  aliases=$(mktemp "$ssh_dir/.ssh2-aliases.XXXXXXXX")
  for label in "${labels[@]}"; do
    printf '%s\n' "$label" >> "$aliases"
  done

  # Strip only our own block. Reject damaged markers and duplicate Host aliases
  # elsewhere in the main file rather than silently changing their precedence.
  source_config=/dev/null
  [[ ! -f $config ]] || source_config=$config
  awk -v names="$aliases" '
    FILENAME == names { aliases[tolower($0)] = 1; next }
    {
      if ($0 == "# BEGIN ssh2 managed hosts") {
        if (inside || ++begins > 1) { error = "Duplicate ssh2 start marker"; exit 1 }
        inside = 1
        next
      }
      if ($0 == "# END ssh2 managed hosts") {
        if (!inside || ++ends > 1) { error = "Unmatched ssh2 end marker"; exit 1 }
        inside = 0
        next
      }
      if (inside) next
      line = $0
      sub(/^[[:space:]]*/, "", line)
      count = split(line, parts, /[[:space:]=]+/)
      if (tolower(parts[1]) == "host") {
        for (i = 2; i <= count; i++) {
          name = parts[i]
          gsub(/^"|"$/, "", name)
          if (tolower(name) in aliases) {
            error = "SSH alias already defined outside ssh2 block: " name
            exit 1
          }
        }
      }
      print
    }
    END {
      if (!error && (inside || begins != ends)) error = "Unmatched ssh2 start marker"
      if (error) { print error > "/dev/stderr"; exit 1 }
    }
  ' "$aliases" "$source_config" > "$tmp" || exit 1

  printf '# BEGIN ssh2 managed hosts\n' >> "$tmp"
  for (( i=0; i<${#labels[@]}; i++ )); do
    printf 'Host %s\n    HostName %s\n' "${labels[$i]}" "${ips[$i]}" >> "$tmp"
  done
  printf '# END ssh2 managed hosts\n' >> "$tmp"
  chmod 600 "$tmp"
  if [[ -f $config ]] && cmp -s "$tmp" "$config"; then
    printf 'SSH aliases already current in %s\n' "$config"
  else
    mv -- "$tmp" "$config"
    printf 'Updated SSH aliases in %s\n' "$config"
  fi
)
