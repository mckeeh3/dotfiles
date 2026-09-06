# Personal overrides, applied after Omarchy's defaults.
# Omarchy already initializes Bash completion, fzf, zoxide, and Starship.
shopt -s autocd histappend cmdhist lithist
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups

# Share new history entries without clearing/reloading the entire history.
# Preserve both the previous exit status (for Starship) and existing hooks.
_dotfiles_history_sync() {
  local last_status=$?
  if [[ -n ${HISTFILE:-} ]]; then
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

# Esc for normal mode, i for insert mode.
set -o vi
