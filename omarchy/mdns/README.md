# SSH discovery on the home LAN

`ssh2` automatically merges manual `ssh2.config` targets with mDNS `_ssh._tcp`
services. Manual targets remain first and keep their labels and SSH config
behavior. Advertised endpoints use a safe hostname label, prompt for a username
(Enter uses your local username), and connect to the advertised port. Service
names and TXT records never supply SSH options, usernames, or commands.

```bash
ssh2                   # Manual targets + a bounded mDNS snapshot
ssh2 --no-mdns         # Manual config only; no discovery dependencies
ssh2 --scan            # Existing TCP-22 scan, independent of mDNS
```

Manual config is still `label address`, one target per line; addresses may also
be SSH aliases/hostnames. Use `~/.ssh/config` for usernames, nonstandard ports,
and IPv6-only machines. No config is required when mDNS supplies targets, and
no discoveries are ever written to the config. For duplicate address+port or
`.local` hostname+port records, the manual entry wins (manual entries are treated
as port 22 for discovery deduplication; arbitrary SSH aliases are not resolved).
An SSH alias using a different port may therefore still appear separately.

## Opt-in Omarchy setup

Run in a visible terminal, after reviewing your SSH authentication settings:

```bash
bash omarchy-setup.sh --setup-mdns
# Or, when installing the Zsh profile:
bash omarchy-zsh-setup.sh --setup-mdns
# Or just set up discovery/advertising without touching shell profiles:
bash omarchy/mdns/setup.sh --apply
```

**This explicitly enables incoming SSH access and advertises the PC to the LAN.**
The helper installs only missing `avahi`/`openssh` packages via `omarchy pkg add`,
then enables/starts `avahi-daemon.service` and `sshd.service` only if needed.
Existing SSH authentication settings, firewall rules, NSS settings, and foreign
Avahi advertisements are not changed. Nothing privileged happens when merely
running `ssh2`, or when running profile setup without `--setup-mdns`.

The Bash installer links the picker into `~/.local/bin`; the Zsh installer does
so when passed `--setup-mdns`. Both refuse to overwrite a different command/link.
If using only the standalone helper, run `./ssh2` directly from this repository.
Keep the repository (including `lib/ssh2-mdns.sh`) in place; the picker follows
its symlinks to find both its helper and config.

The helper reads the effective port with `sudo sshd -T` and installs
`/etc/avahi/services/ssh2.service` with that port. It requires the standard Arch
`/usr/bin/sshd -D` service, one port, and wildcard IPv4 listening. Socket
activation, command-line overrides, multiple ports, restricted listen addresses,
missing host keys, and config errors stop setup with a diagnostic rather than
advertising a guessed port or changing SSH settings. If host keys are missing,
review and run `sudo ssh-keygen -A`, then retry. Existing running daemons are not
restarted: if you changed SSH configuration, apply it yourself before setup.

An identical generated service is reused on reruns. Differing files, symlinks,
or other files containing an SSH advertisement cause an actionable refusal;
review the existing advertisement and its port instead of overwriting it. If a
valid advertisement already exists, retain it and manually ensure Avahi/sshd are
running; you do not need another service file. Unrelated services are preserved.
Avahi picks up new service files automatically. Custom Avahi settings that
restrict interfaces, disable IPv4, or disable publishing need manual review.

Give each PC a unique hostname. Verify from **another PC on the same LAN**:

```bash
avahi-browse --resolve --terminate _ssh._tcp
ssh2
```

## macOS

Bonjour (`dns-sd`) and `dscacheutil` are built in. The picker uses Bonjour's zone
output to discover SRV records, then resolves IPv4 addresses for connection and
deduplication. No Python, Avahi, GNU timeout, or Homebrew dependency is needed.

To advertise a Mac, enable **System Settings → General → Sharing → Remote
Login**, restricting access to intended users. Check from another machine with
`dns-sd -B _ssh._tcp local.` (Ctrl-C stops the browser). If no advertisement
appears, `dns-sd -R "My Mac SSH" _ssh._tcp local. 22` is a temporary advertisement
while that command runs; replace 22 with the actual SSH port. Persistent custom
registration requires a separately configured LaunchAgent/LaunchDaemon.

## Limits and security

- Automatic discovery is **IPv4 only** in this version. Manual IPv6/SSH alias
  entries remain supported.
- Discovery tools have a five-second total waiting budget. Bonjour browses for
  two seconds, sharing the remaining budget across address lookups. Parsing and
  menu merging add a small, capped amount of work after capture; this is not a
  hard real-time deadline for the whole picker.
- Each tool's raw stdout capture is limited to **at most 64 KiB** (32 KiB on
  shells using 512-byte file-limit blocks); stderr is discarded. Only the first
  **256 complete lines** are inspected and at most **64 distinct candidate
  services** are validated/resolved and merged. Incomplete trailing records are
  discarded. Duplicate or invalid candidates can reduce the resulting menu.
  Manual entries are not capped and take precedence; their hostnames are
  normalized once, rather than once per comparison. No discovery comparison
  spawns a subprocess.
- Slow/late services or records beyond these limits may be missing; rerun to
  refresh, or add important PCs to the manual config. Partial complete results
  survive a timeout/output limit. Missing/failing discovery tools fall back to
  manual entries.
- The snapshot is not a liveness check. Advertisements can be stale or spoofed;
  SSH authentication and host-key verification stay enabled and unchanged.
- mDNS generally stays within the same LAN/VLAN. Guest Wi-Fi/client isolation,
  multicast filtering, and firewalls may block it. Allow UDP 5353 multicast and
  the configured SSH TCP port only on trusted networks as appropriate. This
  setup does not open firewall ports or install multicast reflectors.
- Discovery advertises network access, not Git/config write access. New PCs
  never receive credentials to modify this repository or other PCs' config.

To stop advertising, remove only the generated `ssh2.service` file after review.
Disable SSH/Avahi only if you no longer need them for other purposes; setup does
not record their previous state or provide an automatic rollback.

## Offline validation

```bash
for file in ssh2 lib/ssh2-mdns.sh omarchy/mdns/setup.sh omarchy-setup.sh omarchy-zsh-setup.sh; do
  bash -n "$file" || break
done
python3 -m unittest discover -s tests -p 'test_ssh2*.py'
```

Tests mock discovery, SSH, packages, sudo and systemd and use temporary service
paths. They do not scan your LAN, install packages, or modify live services.
