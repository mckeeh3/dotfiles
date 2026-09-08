# Omarchy Bash profile

Reusable Bash customizations layered around Omarchy's packaged defaults, plus a
tracked Starship prompt. This profile does not install Zsh, change the login
shell, or modify anything under `/usr/share/omarchy/`. Do **not** run
`arch-linux-setup.sh` for this profile: that installer deploys the older Zsh and
application configs.

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
installs `src/omarchy/starship.toml` to `${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml`.
Existing settings are **not merged**: move any additional personal settings you
want to keep into the local override file described below. The installer captures
the profile and prompt in this repo, not arbitrary changes made to your live
files later.

- Each `.bashrc` replacement saves the previous file in `~/.bashrc.bak.<unique>/.bashrc`.
- Each Starship replacement saves the previous config in `~/.config/starship.toml.bak.<unique>/starship.toml`.
- Backups stay in your home/config directory, never in the repository.
- Symlinks are backed up as symlinks; their targets are not modified.
- An identical installation is a no-op, including with replacement flags.
- Modified loaders or prompt configs require explicit replacement permission.
- No packages are installed, and no unrelated live configuration files are changed.

Open a **new Bash terminal** afterward. Do not source the new profile over your
old initialized shell: old prompt hooks, aliases, and integrations may remain.
Keep the repo in place. If you move it, rerun the installer from its new location
with `--replace-bashrc` to update the loader.

Omarchy's normal `~/.bash_profile` sources `~/.bashrc`. The installer leaves login
files alone; if you have customized yours, ensure it still does so. If an Omarchy
update/reset replaces `.bashrc` or `starship.toml`, review the new defaults and
rerun the installer.

## Dependencies

The installer reports missing commands/files without changing packages. Most
are already provided by Omarchy. If needed, use the following commands yourself:

```bash
omarchy pkg add bash-completion git fzf zoxide starship eza bat ripgrep
omarchy pkg aur add blesh-git
```

`blesh-git` supplies `/usr/share/blesh/ble.sh` on the machine this profile was
captured from. Missing ble.sh disables suggestions/highlighting but does not
prevent Bash from starting. `eza`, `bat`, and `rg` aliases are enabled only when
the commands exist. Omarchy handles initialization of Bash completion, fzf,
zoxide, Starship, and mise; this profile does not initialize them a second time.
The included Starship config starts from Starship's Tokyo Night preset.

## Load order and features

1. `bash/init.sh` loads Omarchy's environment bootstrap, even for non-interactive
   shells, then stops unless Bash is interactive.
2. `bash/before.sh` loads ble.sh without attaching it (except in a dumb terminal).
3. Omarchy's `default/bash/rc` loads the maintained upstream shell defaults.
4. `bash/after.sh` adds personal history settings, aliases, helpers, and Vi mode.
5. An optional local override is sourced, then ble.sh attaches.

Repeatedly sourcing the loader in the same shell does not reinitialize it. Open
a new terminal to apply changes to the tracked profile or local overrides.

Included customizations:

- Autosuggestions and syntax highlighting via ble.sh; Vi editing (`Esc`, then `i`).
- `autocd`: enter a directory path without typing `cd`.
- Large history, multiline entries, and append/import of new history at each
  prompt. Existing prompt hooks and the previous command's exit status survive.
  Unlike the original configuration, this does not clear/reload all history at
  every prompt. It is not a transactional cross-shell deduplication mechanism.
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
for file in src/omarchy/bash/*.sh src/omarchy/tests/*.sh; do
  bash -n "$file" || break
done
STARSHIP_CONFIG=src/omarchy/starship.toml starship prompt >/dev/null
bash src/omarchy/tests/test.sh
```

The test suite uses temporary homes, a mock Omarchy path for installer checks,
and isolated hook tests. It checks reruns, consent, backups, symlinks, paths with
spaces/metacharacters, prompt-hook preservation, and Git/directory helpers.
It never installs packages or changes your live configuration.

After installation, manually verify suggestions/highlighting, Vi mode, fzf key
bindings, the Tokyo Night Starship prompt, `z`, Git aliases, and history sharing
in two fresh terminals.
