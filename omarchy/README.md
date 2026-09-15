# Omarchy Bash profile

For the agent-readable desktop and shell replication guide, see
[SETUP.md](SETUP.md). For optional Java and Maven installation through SDKMAN!,
see [Java/Maven setup](java/README.md). When setting up Pi, also install the
[global Pi packages](SETUP.md#global-pi-packages): `pi-subagents` and `pi-web-access`.

Reusable Bash customizations layered around Omarchy's packaged defaults, plus a
tracked Starship prompt. Bash stays the system/login-shell fallback; use the
[separate Zsh setup](zsh/README.md) for Ghostty. This profile does not install Zsh, change the login
shell, or modify anything under `/usr/share/omarchy/`. Do **not** run
`arch-linux-setup.sh` for this profile: that installer deploys the older Zsh and
application configs.

## Shared apps on every Omarchy PC

See [shared package setup](packages/README.md) for repository and AUR app lists,
including LocalSend and KeePass. Preview with `bash omarchy/packages/setup.sh`, then
install missing apps with `bash omarchy/packages/setup.sh --apply` after review.
This is a separate step; the shell installers below remain configuration-only.

## Install on a new Omarchy machine

Clone this repository to a permanent location, then run from its root:

```bash
bash omarchy-setup.sh
```

Omarchy normally already provides a `.bashrc`, so the installer will refuse to
replace it until you explicitly opt in. Review your existing file, then run:

```bash
bash omarchy-setup.sh --replace-bashrc --replace-starship
```

This replaces `.bashrc` with a small loader pointing at this repository and
installs `omarchy/starship.toml` (the Arch Powerline prompt) to
`${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml`.
It also links `~/.local/bin/ssh2` to this repository's `ssh2` script, which reads
`ssh2.config` beside the original script. An existing different command or link
is left untouched; review and move it aside before rerunning the installer.
Existing settings are **not merged**: move any additional personal settings you
want to keep into the local override file described below. The installer captures
the profile and prompt in this repo, not arbitrary changes made to your live
files later.

For automatic SSH discovery when adding this PC to your home LAN, optionally
add `--setup-mdns` to the installer (also supported by `omarchy-zsh-setup.sh`).
This installs only missing Avahi/OpenSSH packages, enables **incoming SSH access**,
and advertises the configured port without changing authentication or firewall
settings. Avahi already installed/running is reused. The standalone
`bash omarchy/mdns/setup.sh --apply` performs only this setup. See
[mDNS setup and limitations](mdns/README.md) before enabling it. `ssh2` merges
discoveries with `ssh2.config`; `ssh2 --no-mdns` keeps config-only behavior.

Additional prompt presets live in `omarchy/starship-prompts/`. After opening
a fresh shell, run `starship-prompt list` to see them, then select one with:

```bash
starship-prompt easy-term
```

For the two-line Arch screenshot-style prompt, select `starship-prompt arch-powerline`.
It shows the OS, full directory path, Git branch and change counts on the left;
a green success check or red numeric exit code and a seconds clock on the right.
Only SSH sessions show `with user@hostname` and a globe; both identity fields
are hidden locally, including in root/su sessions.
Install/select the preset on the remote server too to get this prompt over SSH.
A Nerd Font is required for the icons and Powerline separators. The right-hand
details use Starship's `$fill` on the first line (rather than a native
`right_prompt`) so Bash and Zsh both leave the second line for command input.
Long paths may crowd the right side in narrow terminals.

This copies the selected preset to `${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml`.
Open a fresh terminal, or run `exec bash`, to ensure every prompt hook is using
it. Use `starship-prompt current` to identify the active tracked preset.

- Each `.bashrc` replacement saves the previous file in `~/.bashrc.bak.<unique>/.bashrc`.
- Each Starship replacement saves the previous config in `~/.config/starship.toml.bak.<unique>/starship.toml`.
- Backups stay in your home/config directory, never in the repository.
- Symlinks are backed up as symlinks; their targets are not modified.
- An identical installation is a no-op, including with replacement flags.
- Modified loaders or prompt configs require explicit replacement permission.
- Without `--setup-mdns`, no packages are installed and no system services are changed.

Open a **new Bash terminal** afterward. Do not source the new profile over your
old initialized shell: old prompt hooks, aliases, and integrations may remain.
Keep the repo in place. If you move it, rerun the installer from its new location
with `--replace-bashrc` to update the loader. Move the old `~/.local/bin/ssh2`
link aside first so the installer can link the new location.

Omarchy's normal `~/.bash_profile` sources `~/.bashrc`. The installer leaves login
files alone; if you have customized yours, ensure it still does so. If an Omarchy
update/reset replaces `.bashrc` or `starship.toml`, review the new defaults and
rerun the installer.

## Dependencies

The profile dependency check reports missing commands/files without changing packages. Most
are already provided by Omarchy. If needed, use the following commands yourself:

```bash
omarchy pkg add bash-completion git fzf zoxide starship eza bat ripgrep
```

`eza`, `bat`, and `rg` aliases are enabled only when the commands exist.
Omarchy handles initialization of Bash completion, fzf, zoxide, Starship, and
mise. This profile restores native Readline Ctrl+R after Omarchy's fzf setup;
other fzf integrations remain available. ble.sh is no longer loaded or required.
The default Starship config is the Arch Powerline preset described above.
Tokyo Night remains available with `starship-prompt tokyo-night`.

## Load order and features

1. `bash/init.sh` loads Omarchy's environment bootstrap, even for non-interactive
   shells, then stops unless Bash is interactive.
2. Omarchy's `default/bash/rc` loads the maintained upstream shell defaults.
3. `bash/after.sh` adds history settings, aliases, helpers, and native Emacs-mode
   Readline editing with Ctrl+R reverse search.
4. SDKMAN is initialized if installed (see the optional Java/Maven setup above).
5. An optional local override is sourced.

Repeatedly sourcing the loader in the same shell does not reinitialize it. Open
a new terminal to apply changes to the tracked profile or local overrides.

Included customizations:

- Native Bash editing, without ble.sh suggestions, highlighting, or Vi mode.
- Ctrl+R incrementally searches history; press Ctrl+R again for older matches.
  Enter runs the match; Esc leaves it on the command line for editing, and
  Ctrl+G cancels the search. Unlike the old picker, Enter executes immediately.
- Up/Down retain Omarchy's prefix-history search. Ctrl+P/Ctrl+N browse previous/
  next commands. `!!` reruns the last command; `!prefix` reruns the latest command
  starting with that prefix. These execute on Enter, so review before rerunning.
- `autocd`: enter a directory path without typing `cd`.
- Large, timestamp-delimited history with multiline entries, appended/imported
  at each prompt. Existing prompt hooks and the previous command's exit status
  survive. This is not a transactional cross-shell deduplication mechanism.
- Oh My Zsh-style Git aliases and main/development branch helpers.
- `git --no-pager`, customized `ls`/`ll`, `cat` → `bat`, and `grep` → `rg`.
- `d` lists the directory stack; `1`–`5` visit its indexed entries using Bash
  syntax. Populate the stack with `pushd`/`popd`; ordinary `cd` is not auto-pushed.

Some overrides intentionally differ from Omarchy: `d` means `dirs -v` rather
than Docker, and `gcm` checks out the main branch rather than committing with a
message (`gcmsg` does that). Use `command cat`, `command grep`, or `command git`
to bypass the corresponding aliases when you need standard command behavior.

## Local-only settings and secrets

Put machine-specific overrides in:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/bash.local.sh
```

The installer does not create or copy this file. Keep it outside this repository.
Use a keyring/secret manager for credentials; do not add secrets to tracked
profiles. History, caches, and tool state are not captured. Repository ignore
rules also exclude backup files and `*.local.sh` overrides as a safeguard, not
as a substitute for reviewing `git diff` before committing.

## Restore the previous configuration

Keep another terminal open. Replace `XXXXXXXX` below with the backup suffix
printed by the installer, and review that backup before restoring it:

```bash
# Remove only the generated files, then restore the original files or symlinks.
rm -- "$HOME/.bashrc" "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
cp -a -- "$HOME/.bashrc.bak.XXXXXXXX/.bashrc" "$HOME/.bashrc"
cp -a -- "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml.bak.XXXXXXXX/starship.toml" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
```

Open a new terminal. Backups and the repository are retained for your review.

## Validate

```bash
bash -n omarchy-setup.sh
for file in omarchy/bash/*.sh omarchy/tests/*.sh; do
  bash -n "$file" || break
done
STARSHIP_CONFIG=omarchy/starship.toml starship prompt >/dev/null
for prompt in omarchy/starship-prompts/*.toml; do
  STARSHIP_CONFIG="$prompt" starship prompt >/dev/null || break
done
bash omarchy/tests/test.sh
# Requires Python 3; uses a temporary HOME and a PTY.
python3 omarchy/tests/history-interactive.py
```

The test suite uses temporary homes, a mock Omarchy path for installer checks,
and isolated hook tests. It checks reruns, consent, backups, symlinks, paths with
spaces/metacharacters, prompt-hook preservation, and Git/directory helpers.
It never installs packages or changes your live configuration. The interactive
regression test checks native Ctrl+R after an fzf-style binding, command recall,
and `!!` rerun using synthetic history.

After installation, manually verify Ctrl+R, command recall, the Starship prompt,
`z`, Git aliases, and history sharing in two fresh Bash terminals. Existing
installations pointing at this repo need only a fresh Bash process (`exec bash`),
not a reinstall. Do not source over an already attached ble.sh session. No
packages, history files, Ghostty settings, or Zsh configuration are removed.
