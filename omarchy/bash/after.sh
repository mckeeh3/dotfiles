# Personal overrides, applied after Omarchy's defaults.
# Omarchy already initializes Bash completion, fzf, zoxide, and Starship.
shopt -s autocd histappend cmdhist lithist
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups

# Plain Bash fallback: append/import new entries without clearing history.
# ble.sh uses history_share below instead of this hook's raw history -n.
# Preserve both the previous exit status (for Starship) and existing hooks.
_dotfiles_history_sync() {
  local last_status=$?
  if [[ -z ${BLE_VERSION:-} && -n ${HISTFILE:-} ]]; then
    history -a
    history -n
  fi
  return "$last_status"
}
if [[ ";${PROMPT_COMMAND[*]-};" != *'_dotfiles_history_sync'* ]]; then
  PROMPT_COMMAND=(_dotfiles_history_sync "${PROMPT_COMMAND[@]}")
fi

alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias -- -='cd -'
alias git='git --no-pager'

# Oh My Zsh git-plugin style aliases (override Omarchy's gcm intentionally).
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gap='git apply'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gc='git commit --verbose'
alias gc!='git commit --verbose --amend'
alias gca='git commit --verbose --all'
alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcd='git checkout $(git_develop_branch)'
alias gcm='git checkout $(git_main_branch)'
alias gd='git diff'
alias gdca='git diff --cached'
alias gds='git diff --staged'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gl='git pull'
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias gm='git merge'
alias gp='git push'
alias gpd='git push --dry-run'
alias gpf='git push --force-with-lease'
alias gpsup='git push --set-upstream origin $(git_current_branch)'
alias gr='git remote'
alias grv='git remote --verbose'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase --interactive'
alias grs='git restore'
alias grst='git restore --staged'
alias gst='git status'
alias gsb='git status --short --branch'
alias gss='git status --short'
alias gstaa='git stash apply'
alias gstc='git stash clear'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --text'
alias gsta='git stash push'
alias gsw='git switch'
alias gswc='git switch --create'
alias gwt='git worktree'
alias gwta='git worktree add'
alias gwtls='git worktree list'

git_current_branch() {
  command git branch --show-current 2>/dev/null
}

git_main_branch() {
  command git rev-parse --git-dir >/dev/null 2>&1 || return
  local ref
  for ref in main trunk mainline default master; do
    if command git show-ref -q --verify "refs/heads/$ref"; then
      printf '%s\n' "$ref"
      return
    fi
  done
  printf 'master\n'
}

git_develop_branch() {
  command git rev-parse --git-dir >/dev/null 2>&1 || return
  local ref
  for ref in dev develop development; do
    if command git show-ref -q --verify "refs/heads/$ref"; then
      printf '%s\n' "$ref"
      return
    fi
  done
  printf 'develop\n'
}

# Use pushd/popd to populate the stack; d lists its numbered entries.
# Bash does not support Zsh's `cd -1` syntax. Quote paths containing spaces.
_dotfiles_cd_stack() {
  local destination
  destination=$(dirs -l +"$1") || return
  builtin cd -- "$destination"
}
alias d='dirs -v'
alias 1='_dotfiles_cd_stack 1'
alias 2='_dotfiles_cd_stack 2'
alias 3='_dotfiles_cd_stack 3'
alias 4='_dotfiles_cd_stack 4'
alias 5='_dotfiles_cd_stack 5'

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto'
  alias ll='eza -lah --icons=auto --git'
else
  alias ll='ls -lah'
fi
if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
fi
if command -v rg >/dev/null 2>&1; then
  alias grep='rg'
fi

_DOTFILES_OMARCHY_STARSHIP_PROMPT_DIR=$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../starship-prompts" >/dev/null 2>&1 && pwd)

starship-prompt() {
  local prompt_dir config_home target name source found
  prompt_dir=$_DOTFILES_OMARCHY_STARSHIP_PROMPT_DIR
  if [[ ! -d $prompt_dir ]]; then
    printf 'Starship prompt directory not found. Expected it next to the Bash profile.\n' >&2
    return 1
  fi
  config_home=${XDG_CONFIG_HOME:-$HOME/.config}
  target=$config_home/starship.toml

  case ${1:-list} in
    list|--list|-l)
      printf 'Available Starship prompts:\n'
      found=0
      for source in "$prompt_dir"/*.toml; do
        [[ -e $source ]] || continue
        found=1
        name=${source##*/}
        printf '  %s\n' "${name%.toml}"
      done
      if (( ! found )); then
        printf '  (none found in %s)\n' "$prompt_dir"
      fi
      printf '\nUse: starship-prompt <name>\n'
      ;;
    current|--current|-c)
      if [[ -f $target ]]; then
        for source in "$prompt_dir"/*.toml; do
          [[ -e $source ]] || continue
          if cmp -s -- "$source" "$target"; then
            name=${source##*/}
            printf '%s\n' "${name%.toml}"
            return
          fi
        done
      fi
      printf 'custom\n'
      ;;
    help|--help|-h)
      printf 'Usage: starship-prompt [list|current|<name>]\n'
      ;;
    *)
      name=$1
      if [[ ! $name =~ ^[[:alnum:]_.-]+$ ]]; then
        printf 'Invalid Starship prompt name: %s\n' "$name" >&2
        return 1
      fi
      source=$prompt_dir/$name.toml
      if [[ ! -r $source ]]; then
        printf 'Unknown Starship prompt: %s\n' "$name" >&2
        starship-prompt list >&2
        return 1
      fi
      mkdir -p -- "$config_home"
      cp -- "$source" "$target"
      printf 'Selected Starship prompt: %s\n' "$name"
      printf 'Open a fresh terminal, or run: exec bash\n'
      ;;
  esac
}

# Esc for normal mode, i for insert mode.
set -o vi

# Keep history search compact; preserve any machine-specific fzf options.
export FZF_CTRL_R_OPTS="--height=40% --layout=reverse --border${FZF_CTRL_R_OPTS:+ $FZF_CTRL_R_OPTS}"

if [[ ${BLE_VERSION:-} ]]; then
  # Let ble.sh manage sharing; raw prompt-time imports can corrupt its history.
  bleopt history_share=1

  # Suggest one historical command, without running completion while typing.
  # Full completion menus remain available on Tab only.
  bleopt complete_auto_complete=1
  bleopt complete_auto_complete_opts=syntax-disabled
  bleopt complete_auto_menu=0

  # Readline's fzf bindings alone are not enough when ble.sh owns line editing.
  if command -v fzf >/dev/null 2>&1; then
    ble-import integration/fzf-completion
    ble-import integration/fzf-key-bindings
  fi

  for _dotfiles_keymap in emacs vi_imap vi_nmap; do
    ble-bind -m "$_dotfiles_keymap" -f up history-substring-search-backward
    ble-bind -m "$_dotfiles_keymap" -f down history-substring-search-forward
  done
  unset _dotfiles_keymap

  # Cancel even an in-progress search, discard its query, and leave a fresh
  # prompt. Scope Esc to search so normal Vi editing remains unchanged.
  ble/widget/dotfiles-history-cancel() {
    ble/util/fiberchain#clear
    ble/widget/nsearch/cancel
    ble/widget/discard-line
  }
  ble-bind -m nsearch -f ESC dotfiles-history-cancel
  ble-bind -m nsearch -f 'C-[' dotfiles-history-cancel
elif [[ $- == *i* ]]; then
  # The same substring navigation when ble.sh is unavailable.
  for _dotfiles_keymap in emacs-standard vi-insert vi-command; do
    bind -m "$_dotfiles_keymap" '"\e[A": history-substring-search-backward'
    bind -m "$_dotfiles_keymap" '"\e[B": history-substring-search-forward'
  done
  unset _dotfiles_keymap
fi
