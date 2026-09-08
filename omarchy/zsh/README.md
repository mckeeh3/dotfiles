# Omarchy Zsh in Ghostty

Use Zsh for Ghostty terminals while retaining Bash as the account/login shell
and keeping the existing [Bash profile](../README.md) as a fallback. This is a
standalone Zsh configuration inspired by `arch-linux/zshrc`, not a copy of that
workstation's SDKs, secrets, Powerlevel10k, Powerline, or Oh My Zsh installation.
It never sources Omarchy's Bash rc or changes `/usr/share/omarchy/`.

## Install

From a visible terminal, install the packaged dependencies if needed:

```bash
omarchy pkg add ghostty zsh zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
# Normally already installed on Omarchy:
omarchy pkg add fzf starship zoxide mise
```

From the repository root:

```bash
bash omarchy-zsh-setup.sh --ghostty
# Only if you have reviewed an existing, different ~/.zshrc:
bash omarchy-zsh-setup.sh --replace-zshrc --ghostty
omarchy restart terminal
```

The installer:

- Creates `~/.zshrc` as a loader pointing at this repository.
- With `--ghostty`, appends an include of `omarchy/ghostty-zsh.conf` to
  `${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config`. This sets
  `command = /usr/bin/zsh` without replacing your font, theme, or keybindings.
- Backs up changed existing files in private `*.bak.XXXXXXXX` directories next
  to the files. Identical reruns do not add backups or duplicate includes.
- Leaves `.bashrc`, the login shell, the selected Starship config, existing
  history, and the desktop's default terminal application unchanged.
- Installs no packages and refuses custom `ZDOTDIR` or symlinked Ghostty config
  setups; those need manual configuration.

Keep this repository in place. If you move it, update the loader and Ghostty
include (remove the old include before rerunning). An existing `initial-command`
in Ghostty, or an explicit `ghostty -e ...`, can override the first shell.

**Open a new Ghostty window** to use Zsh. Existing shells are not replaced by a
config reload. On this machine the desktop terminal launcher selected Foot at
setup time: the terminal shortcut will still open Foot unless you separately
change your preferred terminal. SSH and other terminal applications still use
Bash by default. `echo $ZSH_VERSION` identifies a running Zsh; `$SHELL` may still
say Bash because it describes the account's login shell.

## Behavior

- Type `list`, then Up/Down to recall matching history commands one at a time.
  Matches can occur anywhere in a command. Both terminal arrow encodings work.
- Esc immediately after Up/Down discards the result and returns to an empty
  insert-mode prompt. Outside history navigation, Esc enters Vi normal mode;
  `i` returns to insert mode. Ctrl+C also abandons the current command line.
- Ctrl+R opens fzf history search. Enter selects a command for editing, not
  immediate execution; Esc dismisses the picker.
- Suggestions come from history only. Right-arrow accepts an inline suggestion
  at the end of the command. Tab explicitly requests completion.
- Syntax highlighting, Vi editing, Oh My Zsh-style Git aliases, `autocd`, and
  directory-stack shortcuts (`d`, `1`–`5`) are enabled.
- mise, zoxide (`z`), fzf, and Starship use their native Zsh integrations.
  `starship-prompt list/current/<name>` uses the existing tracked prompt presets.
- Zsh stores timestamp-delimited history in `~/.zsh_history` and shares it across
  Zsh sessions. It deliberately does not import or share `~/.bash_history`:
  Bash and Zsh have different multiline history formats. Initial Zsh history is
  empty; it builds as you run commands. Existing Bash history is retained.

No prompt framework or plugin manager is needed. Plugins come from Arch
packages and are updated by the package manager. Missing optional tools are
skipped; missing plugins produce a startup warning.

## Local overrides

Put machine-specific settings and secrets outside the repository:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/zsh.local.zsh
```

This loads after tool integrations and keybindings, but before syntax
highlighting. Repeatedly sourcing `.zshrc` does not reinitialize the profile;
open a new shell or run `exec zsh` to apply edits.

## Validation

```bash
bash -n omarchy-zsh-setup.sh
zsh -n omarchy/zsh/zshrc
zsh -n omarchy/zsh/aliases.zsh
bash omarchy/tests/zsh-setup.sh
python3 omarchy/tests/zsh-interactive.py
ghostty +validate-config
```

Tests use temporary homes, synthetic history, and a PTY. They check installer
consent/backups/reruns, path quoting, preservation of Bash and Starship config,
substring arrows, Esc cancellation, and ordinary Vi mode without executing
recalled commands or touching live history.

## Roll back

Remove the dotfiles `config-file` include from Ghostty's config (or restore its
printed backup), reload terminal configuration, and open a new Ghostty window.
It will again use your login shell, Bash. If needed, restore `.zshrc` from its
backup; if there was none, remove only the generated loader. Keep history files
and the existing Bash setup. No `chsh` is necessary in either direction.
