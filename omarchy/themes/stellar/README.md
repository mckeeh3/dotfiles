# Stellar selection contrast

Local palette override for the installed Stellar theme. Sets dark selection text
on the theme's near-white highlight, fixing invisible selected Yes/No buttons in
Gum and selected text in Ghostty and other generated terminal configs. Normal
foreground text stays light on the dark terminal background.

After installing Stellar, inspect `~/.config/omarchy/themes/stellar/colors.toml`.
If it has other custom colors, back it up and merge only `selection = "#f0f6fc"`,
`selection_background = "#f0f6fc"`, and `selection_foreground = "#0d1117"`.
Otherwise, after approving replacement, run from the dotfiles repository root:

```bash
(
  set -e
  target=$HOME/.config/omarchy/themes/stellar/colors.toml
  if ! cmp -s omarchy/themes/stellar/colors.toml "$target"; then
    # Inspect symlinks before replacement; do not write through them.
    if [ -L "$target" ]; then
      printf 'Palette is a symlink; review its target before proceeding.\n' >&2
      exit 1
    fi
    mkdir -p "$(dirname "$target")"
    if [ -f "$target" ]; then
      backup=$(mktemp -d "$HOME/.config/omarchy/themes/stellar-colors.bak.XXXXXXXX")
      cp -a -- "$target" "$backup/colors.toml"
      printf 'Palette backup: %s\n' "$backup/colors.toml"
    fi
    cp omarchy/themes/stellar/colors.toml "$target"
    OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy theme set stellar
  fi
)
```

If the palette already matches, skip replacement. Reapply Stellar with
`OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy theme set stellar` only if it is not
active or generated colors are stale. The setting preserves the current wallpaper.
Verify that `~/.local/state/omarchy/current/theme/gum_env.lua` sets the selected
foreground to `#0d1117` and selected background to `#f0f6fc`.

## Stale Gum environment

A correct generated theme does not change environment variables inside existing
processes. Inspect the affected shell and the user service manager:

```bash
printenv GUM_CONFIRM_SELECTED_FOREGROUND GUM_CONFIRM_SELECTED_BACKGROUND
systemctl --user show-environment | grep '^GUM_.*SELECTED.*='
```

For active Stellar with the palette above, selected foreground values must be
`#0d1117`, not `#f0f6fc`. If stale, save their previous values outside the repository
before updating them. Run in the affected Bash or Zsh shell:

```bash
for name in GUM_CONFIRM_SELECTED_FOREGROUND GUM_CHOOSE_SELECTED_FOREGROUND \
  GUM_FILTER_SELECTED_FOREGROUND GUM_FILTER_SELECTED_PREFIX_FOREGROUND \
  GUM_TABLE_SELECTED_FOREGROUND GUM_FILE_SELECTED_FOREGROUND; do
  export "$name=#0d1117"
  systemctl --user set-environment "$name=#0d1117"
done
unset name
```

This updates the current shell and future user services, not existing terminal
servers, tmux/Zellij sessions, or Hyprland's launch environment. Reload Hyprland
with `hyprctl reload` and check `hyprctl configerrors` from the desktop session
if its launch environment is stale. Restart an affected terminal server only
after saving its work, or log out and back in at a convenient time. Do not add
these Stellar-specific exports permanently to a shell profile; other themes
need their own selection colors.

Test with `gum confirm "Is this readable?"`; the prompt performs no action.
Toggle between Yes and No and confirm both selected buttons show dark text.
