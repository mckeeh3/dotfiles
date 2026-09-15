
# Dot files for Mac OSX and Arch Linux systems

## Omarchy (Zsh in Ghostty, Bash as the default)

Use the separate [Omarchy Zsh profile](omarchy/zsh/README.md) for native Zsh
history search, suggestions, highlighting, and Vi editing in Ghostty:

```bash
bash omarchy-zsh-setup.sh --ghostty
```

This keeps Bash as the login shell and preserves the existing Starship prompt.
See the profile documentation for package dependencies, backups, and rollback.
It does not change which terminal application the desktop launcher opens.

## Omarchy (Bash fallback)

Use the separate [Omarchy Bash profile](omarchy/README.md) to install the
Zsh-like Bash customizations while retaining Omarchy's defaults:

```bash
bash omarchy-setup.sh
# To back up and replace an existing .bashrc after reviewing it:
bash omarchy-setup.sh --replace-bashrc
# In a fresh shell, list/select tracked Starship prompt presets:
starship-prompt list
starship-prompt easy-term
```

Do not use `arch-linux-setup.sh` for this profile; it installs the older Zsh and
application configs. Local overrides and installer backups stay outside Git.

## Legacy platform configs

~~~bash
.
├── README.md
└── src
    ├── arch-linux  # <-- common arch linux files
    │   ├── vimrc
    │   └── zshrc
    ├── arch-linux-asrock-x570  # <-- for system specific files
    │   ├── vimrc
    │   └── zshrc
    ├── arch-linux-x99-extreme4  # <-- for system specific files
    │   ├── vimrc
    │   └── zshrc
    ├── mac  # <-- common mac osx files
    │   ├── vimrc
    │   └── zshrc
    ├── mac-2016  # <-- for system specific files
    │   ├── vimrc
    │   └── zshrc
    └── mac-2019  # <-- for system specific files
        ├── vimrc
        └── zshrc
~~~

## SSH target picker

`ssh2` merges targets from `ssh2.config` (format: `label address`) with automatic
mDNS SSH discovery (Avahi on Linux, Bonjour on macOS). Manual targets remain
supported for PCs without mDNS. Press Enter to connect, or `q` to cancel.

```bash
ssh2                          # Configured targets + mDNS (bounded discovery)
ssh2 --no-mdns                # Configured targets only
ssh2 --scan                   # Discover targets on 192.168.7.0/24
ssh2 --scan 192.168.8.0/24     # Discover targets on another IPv4 subnet
```

For Omarchy, `bash omarchy-setup.sh --setup-mdns` (or
`bash omarchy-zsh-setup.sh --setup-mdns`) installs missing Avahi/OpenSSH packages,
enables **incoming SSH access**, and advertises the configured SSH port. Existing
SSH settings and firewall rules are not changed. See [mDNS setup](omarchy/mdns/README.md)
for standalone setup, macOS advertising, manual config, and security limitations.
Automatic discovery is IPv4-only; manual IPv6/SSH aliases still work. Missing or
failing discovery tools fall back to configured targets. Discovered targets
prompt for a username and honor advertised ports; manual entries keep existing
SSH config behavior. Discoveries are never saved to the config.

Scanning requires Nmap (`sudo pacman -S nmap` on Arch, `brew install nmap`
on macOS), but does not require sudo. Only scan networks you own or have
permission to scan. Hosts that ignore ping are included; large subnets or
filtered ports can take a while.

Scan results reuse configured labels, otherwise use reverse-DNS hostnames when
available, falling back to IPs. Scan mode works without a config file and asks
for an SSH username (Enter uses your local username). Discoveries are never
written to the config. An open TCP port 22 does not guarantee an SSH service
or valid login credentials; SSH on other ports is not discovered.

Validation: `bash -n ssh2`, `bash -n lib/ssh2-mdns.sh`, and
`python3 -m unittest discover -s tests -p 'test_ssh2*.py'`
(the tests mock discovery, Nmap, SSH, and privileged setup; no live network or system changes).

## tmux

Use [Awesome Tmux](https://github.com/rothgar/awesome-tmux).

Copy or link to `~/.tmux.conf.local` for custom config settings.

On Arch Linux, install `xclip`.
