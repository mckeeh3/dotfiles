# Selected aliases from arch-linux/zshrc and the Omarchy Bash profile.
# No workstation-specific SDKs, credentials, or competing prompt frameworks.
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias -- -='cd -'
alias vi=vim
alias less='less -X'
alias git='git --no-pager'
alias ip='ip --color=auto'
(( $+commands[helix] )) && alias hx=helix
(( $+commands[zeditor] )) && alias zed=zeditor
(( $+commands[kubectl] )) && alias kc=kubectl

alias g=git
alias ga='git add'
alias gaa='git add --all'
alias gap='git apply'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gc='git commit --verbose'
alias 'gc!=git commit --verbose --amend'
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

git_current_branch() { command git branch --show-current 2>/dev/null; }
git_main_branch() {
  command git rev-parse --git-dir >/dev/null 2>&1 || return
  local ref
  for ref in main trunk mainline default master; do
    if command git show-ref -q --verify "refs/heads/$ref"; then
      print -r -- "$ref"
      return
    fi
  done
  print master
}
git_develop_branch() {
  command git rev-parse --git-dir >/dev/null 2>&1 || return
  local ref
  for ref in dev develop development; do
    if command git show-ref -q --verify "refs/heads/$ref"; then
      print -r -- "$ref"
      return
    fi
  done
  print develop
}

alias d='dirs -v'
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
if (( $+commands[eza] )); then
  alias ls='eza --icons=auto'
  alias ll='eza -lah --icons=auto --git'
  alias llt='eza -l --tree'
else
  alias ll='ls -lah'
fi
(( $+commands[bat] )) && alias cat=bat
(( $+commands[rg] )) && alias grep=rg

# Reuse the existing prompt presets without touching the selected prompt.
starship-prompt() {
  local dir=$_DOTFILES_OMARCHY_ZSH_DIR/../starship-prompts
  local target=${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml
  local file name=${1:-list}
  case $name in
    list|--list|-l)
      print 'Available Starship prompts:'
      for file in "$dir"/*.toml(N); do print -r -- "  ${file:t:r}"; done
      ;;
    current|--current|-c)
      for file in "$dir"/*.toml(N); do
        if cmp -s -- "$file" "$target"; then print -r -- "${file:t:r}"; return; fi
      done
      print custom
      ;;
    help|--help|-h) print 'Usage: starship-prompt [list|current|<name>]' ;;
    *)
      if [[ $name == *[^[:alnum:]_.-]* || ! -r $dir/$name.toml ]]; then
        print -u2 -r -- "Unknown Starship prompt: $name"
        return 1
      fi
      mkdir -p -- "${target:h}"
      cp -- "$dir/$name.toml" "$target"
      print -r -- "Selected Starship prompt: $name. Open a fresh terminal or run: exec zsh"
      ;;
  esac
}
