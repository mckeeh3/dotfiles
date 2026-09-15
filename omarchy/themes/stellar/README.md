# Stellar selection contrast

Local palette override for the installed Stellar theme. Sets dark selection text
on the theme's near-white highlight, fixing invisible selected Yes/No buttons in
Gum and selected text in Ghostty and other generated terminal configs.

After installing Stellar, run from the dotfiles repository root:

```bash
mkdir -p ~/.config/omarchy/themes/stellar
# Preserve an existing palette override before replacing it.
if [ -f ~/.config/omarchy/themes/stellar/colors.toml ]; then
  cp ~/.config/omarchy/themes/stellar/colors.toml \
    ~/.config/omarchy/themes/stellar/colors.toml.bak.$(date +%s)
fi
cp omarchy/themes/stellar/colors.toml ~/.config/omarchy/themes/stellar/colors.toml
OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy theme set stellar
```

Open a new terminal window afterward so it inherits the updated Gum environment.
Test with `gum confirm "Is this readable?"`; the prompt performs no action.
