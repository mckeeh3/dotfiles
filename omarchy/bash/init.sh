# Sourced by ~/.bashrc; keep Omarchy's environment available to SSH commands.
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap
[[ $- != *i* ]] && return

# Avoid duplicate prompt hooks and initialization when ~/.bashrc is sourced again.
[[ ${_DOTFILES_OMARCHY_BASH_LOADED:-} == 1 ]] && return
if [[ ! -r ${OMARCHY_PATH:-/usr/share/omarchy}/default/bash/rc ]]; then
  printf 'dotfiles: Omarchy Bash defaults not found.\n' >&2
  return 1
fi
_DOTFILES_OMARCHY_BASH_LOADED=1
_DOTFILES_OMARCHY_BASH_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

source "${OMARCHY_PATH:-/usr/share/omarchy}/default/bash/rc"
source "$_DOTFILES_OMARCHY_BASH_DIR/after.sh"
unset _DOTFILES_OMARCHY_BASH_DIR

# Machine-specific settings stay outside the repository.
if [[ -r ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/bash.local.sh ]]; then
  source "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/bash.local.sh"
fi
