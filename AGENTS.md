# Repository Guidelines

## Project Structure & Module Organization
This repository stores shell/editor terminal dotfiles for macOS and Arch Linux.

- `src/arch-linux/`: shared Arch configs (`zshrc`, `vimrc`, `alacritty.toml`, etc.)
- `src/mac/`: shared macOS configs with matching file names
- `arch-linux/` and `mac/`: host-level app configs (for example `ghostty-config`)
- `src/tmux/`: tmux local config (`tmux.conf.local`)
- `src/lvim/`: LunarVim config (`config.lua`)
- `src/neovim/scripts/`: helper scripts for moving Neovim profile folders
- `zed/`: editor-specific local settings

Prefer updating platform-shared files under `src/` first, then apply machine-specific overrides only where needed.

## Build, Test, and Development Commands
There is no build step; changes are validated by linting and loading configs.

- `bash -n src/neovim/scripts/*.sh`: syntax-check Neovim helper scripts
- `lua -e "dofile('src/lvim/config.lua')"`: quick syntax check for LunarVim Lua config
- `tmux -f src/tmux/tmux.conf.local -L dotfiles-test new -d && tmux -L dotfiles-test kill-server`: validate tmux config parses
- `git status` and `git diff`: review exact config changes before commit

## Coding Style & Naming Conventions
- Shell scripts: Bash with 2-space indentation; keep scripts idempotent and guard destructive moves with checks.
- Lua (`src/lvim/config.lua`): concise option blocks; group plugin declarations in `lvim.plugins`.
- Config filenames should match target tools exactly (`zshrc`, `vimrc`, `alacritty.toml`).
- New platform files should follow existing layout: `src/<platform>/<tool-file>`.

## Testing Guidelines
No centralized automated test suite exists. Use tool-native parse checks and manual smoke tests:

- Run syntax checks above for touched files.
- For shell changes, open a fresh shell: `zsh -f` then source the updated file selectively.
- For editor/terminal configs, start the tool with the updated config and confirm startup has no errors.

## Commit & Pull Request Guidelines
Recent history uses short, imperative commit subjects (examples: `add helix config`, `housekeeping`).

- Keep subject lines brief, lowercase, and action-focused.
- Group related dotfile updates in one commit; avoid mixing unrelated platforms/tools.
- PRs should include:
  - what changed and why
  - affected paths (example: `src/mac/zshrc`)
  - manual validation steps run
  - screenshots only when UI-facing terminal/editor appearance changes
