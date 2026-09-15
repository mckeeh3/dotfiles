#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} != --apply || $# != 1 ]]; then
  printf 'Usage: bash omarchy/mdns/setup.sh --apply\nEnables incoming SSH and advertises it on the LAN. Run in a visible terminal.\n'
  [[ ${1:-} == --help || $# == 0 ]] && exit 0
  exit 1
fi
printf 'Enabling incoming SSH access and LAN SSH discovery (Avahi).\n'
printf 'Existing SSH authentication settings and firewall rules will not be changed.\n'
command -v pacman >/dev/null || { echo 'This setup requires Omarchy/Arch Linux.' >&2; exit 1; }
dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
service_dir=/etc/avahi/services
target=$service_dir/ssh2.service
missing=()
for package in avahi openssh; do
  pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
done
if (( ${#missing[@]} )); then
  # Omarchy owns privilege elevation for package installation.
  omarchy pkg add "${missing[@]}"
  for package in "${missing[@]}"; do
    pacman -Q "$package" >/dev/null || { echo "Package not installed: $package" >&2; exit 1; }
  done
fi

unsupported() {
  printf 'Cannot automatically advertise SSH: %s\n' "$*" >&2
  printf 'Keep your existing settings; configure an Avahi _ssh._tcp service manually with the actual listening port. See omarchy/mdns/README.md.\n' >&2
  exit 1
}
# Socket activation and command-line overrides can supersede sshd_config.
if systemctl is-active --quiet sshd.socket || systemctl is-enabled --quiet sshd.socket 2>/dev/null; then
  unsupported 'sshd.socket is active/enabled.'
fi
exec_start=$(systemctl show sshd.service --property=ExecStart --value)
[[ $exec_start == *'argv[]=/usr/bin/sshd -D ;'* ]] || unsupported 'nonstandard sshd.service ExecStart; expected /usr/bin/sshd -D.'
if ! effective=$(sudo sshd -T); then
  unsupported 'sshd -T failed. Check sudo access, sshd_config and host keys (sudo ssh-keygen -A if missing), then retry.'
fi
mapfile -t ports < <(printf '%s\n' "$effective" | awk 'tolower($1) == "port" {print $2}' | sort -u)
(( ${#ports[@]} == 1 )) || unsupported 'expected exactly one configured SSH port.'
port=${ports[0]}
[[ $port =~ ^[0-9]{1,5}$ ]] && (( 10#$port > 0 && 10#$port <= 65535 )) || unsupported 'invalid configured SSH port.'
# The generated service advertises all IPv4 interfaces. Do not advertise an
# endpoint that only listens on loopback or selected addresses.
listeners=$(printf '%s\n' "$effective" | awk 'tolower($1) == "listenaddress" {print $2}')
[[ $listeners == *"0.0.0.0:$port"* ]] || unsupported 'SSH is not listening on all IPv4 interfaces.'
while read -r listener; do
  [[ $listener == "0.0.0.0:$port" || $listener == "[::]:$port" ]] || unsupported "restricted ListenAddress: $listener"
done <<< "$listeners"

tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT
sed "s/@PORT@/$port/" "$dir/ssh.service.in" > "$tmp"
# Preflight conflicts before enabling network services. Never replace foreign
# advertisements, symlinks, or user-edited versions of our generated file.
if [[ -e $target || -L $target ]]; then
  [[ -f $target && ! -L $target ]] && cmp -s -- "$tmp" "$target" || unsupported "existing $target differs; review/move it aside yourself before retrying."
fi
shopt -s nullglob
for file in "$service_dir"/*.service; do
  [[ $file == "$target" ]] && continue
  [[ -r $file ]] || unsupported "cannot inspect $file."
  if grep -q '_ssh\._tcp' "$file"; then
    unsupported "existing SSH advertisement in $file; verify its port is $port and retain it instead of installing another."
  fi
done
if [[ ! -e $target ]]; then
  sudo install -d -m 755 "$service_dir"
  sudo install -m 644 "$tmp" "$target"
  printf 'Installed: %s (TCP %s)\n' "$target" "$port"
else
  printf 'Already installed: %s\n' "$target"
fi
for service in avahi-daemon.service sshd.service; do
  if ! systemctl is-enabled --quiet "$service"; then
    sudo systemctl enable "$service"
  fi
  if ! systemctl is-active --quiet "$service"; then
    sudo systemctl start "$service"
  fi
done
printf 'SSH advertisement ready on TCP %s. Verify from another PC with avahi-browse -rt _ssh._tcp.\n' "$port"
printf 'No firewall changes were made. Permit UDP 5353 multicast and TCP %s only on trusted networks as needed.\n' "$port"
