# Reproduce this Omarchy setup (agent runbook)

## Scope and source of truth

This guide captures settings observed on an Omarchy **4.0.3-1** installation,
plus the reusable shell profiles in this repository. It is an audit of current
state, not a complete history of past agent conversations or all system changes.
Differences from packaged defaults do not necessarily prove a user customization.

Use this guide together with [Bash setup](README.md) and
[Zsh setup](zsh/README.md). The repository must remain at its installed location:
shell loaders and the Ghostty include refer to it. Do not copy another user's
absolute paths. Do not run the legacy `arch-linux-setup.sh` on Omarchy.

## Rules for an agent applying this guide

1. Read the target machine's Omarchy instructions and inspect its version,
   existing files, and CLI help before making changes. This installation uses
   Hyprland **Lua**, not older `.conf` syntax; adapt to the target version rather
   than pasting incompatible syntax.
2. Explain proposed changes and obtain consent before replacing existing configs,
   installing packages, or changing default applications/security behavior.
3. Back up each changed existing file outside the repository, preserving symlinks
   and permissions. Inspect symlinks before editing. Merge only the settings below;
   do not overwrite whole configs or duplicate existing blocks/includes on reruns.
4. Never edit `/usr/share/omarchy/`. Read its defaults, but put overrides in
   `~/.config/`. Never run `omarchy refresh ...` without explicit confirmation:
   it resets customization.
5. Keep credentials, SSH host inventories, histories, browser profiles, agent
   sessions, device identifiers, and local overrides out of version control.
6. Before **every setup step**, check whether its desired state is already met.
   If so, skip mutation and report it as already configured. In particular, do not
   rerun installers, reapply themes, update plugins, or rewrite files just because
   a command appears in this guide. Repair only missing or differing settings.
7. Keep a working terminal open. Validate each stage; restore its backup if it
   fails. Report applied, skipped, and unverified settings separately.

## Desired settings

| Area | Observed setting | Portability |
| --- | --- | --- |
| Tiled window gaps | `gaps_in = 2`, `gaps_out = 2` | Portable preference |
| Window opening | `slide`, speed `4.1`, curve `easeOutQuint` | Check curve availability |
| Window closing | `slide`, speed `1.49`, curve `linear` | Check curve availability |
| Fading and layout movement | Keep Omarchy defaults | Do not replace all animations |
| Idle screensaver | 600 seconds (10 minutes) | Confirm preference |
| Idle lock | 660 seconds (11 minutes) | Confirm security preference |
| Display scale | 1.25; `GDK_SCALE=1` | Hardware-dependent; opt in |
| Default desktop terminal | Ghostty | Portable preference |
| Browser | Zen (`zen-browser-bin`), default `zen.desktop` | Install through Omarchy |
| Ghostty shell | `/usr/bin/zsh` | Requires Zsh |
| Zellij | Installed; `default_shell "/usr/bin/zsh"` | Requires Zsh |
| Login apps | Zen on workspace 1; Ghostty + Zellij session `dotfiles` on workspace 4 | Portable preference; see section 7a |
| Account/login shell | `/usr/bin/bash` | Retain; no `chsh` |
| Shell profiles | Repository Bash fallback and Zsh profile | Use existing installers |
| Starship prompt | `omarchy/starship.toml` (Arch Powerline preset) | Default for new installs; existing configs require `--replace-starship` |
| Desktop theme | `stellar` | Install from `cicorias/omarchy-stellar-theme`, then activate (section 5) |
| Default agent | `pi` | Optional; install/authenticate separately |
| Pi packages | `pi-subagents`, `pi-web-access` | Required for Pi setup; install globally for the user (section 5) |

## Shared apps on every Omarchy PC

The desired cross-PC app lists live in [`packages/repo.txt`](packages/repo.txt)
and [`packages/aur.txt`](packages/aur.txt). Read [package setup](packages/README.md)
before applying. These are requested additions, not an installed-package audit.
LocalSend (`localsend`, from Omarchy's repository) is the first shared app;
the AUR list is ready for future additions but currently empty.

After pulling this repository on each PC, preview and obtain consent, then apply
in a visible terminal as the normal user:

```bash
bash omarchy/packages/setup.sh
bash omarchy/packages/setup.sh --apply
```

Already installed names are skipped. This only installs missing entries; it does
not upgrade or remove apps, alter defaults, configure networking, or replace the
shell dependency steps below. Review AUR sources before installation. Report
applied, skipped, and failed packages; do not silently substitute package variants.

## 1. Shells, prompt, and Ghostty

Read both linked shell guides completely for behaviors, consent flags, backups,
local overrides, and rollback. Install missing dependencies through Omarchy's
package interface; do not reinstall everything blindly:

```bash
omarchy pkg add ghostty zsh zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
# Usually already supplied by Omarchy; install only if missing:
omarchy pkg add bash-completion git fzf zoxide starship eza bat ripgrep
```

The profiles also integrate mise when available. Preserve Omarchy's existing
mise installation rather than selecting a conflicting package implementation.

From the repository root, after reviewing existing files:

```bash
bash omarchy-setup.sh --replace-bashrc --replace-starship
bash omarchy-zsh-setup.sh --replace-zshrc --ghostty
```

Replacement flags authorize replacement, not merging. Preserve needed local
settings in the external override files documented in the shell guides first.
The installers are repeatable and save backups when replacing differing files.

The live audited Ghostty config directly set `command = /usr/bin/zsh`.
For new installations, prefer the Zsh installer's managed include of
`omarchy/ghostty-zsh.conf`: it selects Zsh and sets a solid black background
(`background = #000000`, `background-opacity = 1`) without copying an entire
terminal config. Keep the managed include after the Omarchy theme include;
other theme colors remain unchanged. Existing installations using this include
pick up changes on a Ghostty configuration reload (`omarchy restart terminal`).
Reconcile any existing `command`, `initial-command`, or old dotfiles include
before adding it.

Set Ghostty as the preferred desktop terminal through the target version's
Omarchy default-application menu, or back up and edit
`~/.config/xdg-terminals.list` so its first desktop entry is:

```text
com.mitchellh.ghostty.desktop
```

Confirm that desktop entry exists on the target; preserve other fallback entries
if desired. The audited file listed only Ghostty. This is separate from choosing
the shell inside Ghostty. The older Zsh guide's note about Foot describes the
initial setup, not the current terminal preference.

Run `omarchy restart terminal` after reviewing its target-version behavior, then
open a **new Ghostty window**. Existing shells do not turn into Zsh on reload.
Do not change the account's Bash login shell.

### Shell behavior being preserved

- Bash: native Emacs/Readline editing, Ctrl+R reverse history search, no ble.sh;
  Enter executes a selected reverse-search match.
- Zsh: Vi editing, autosuggestions, syntax highlighting, substring-history arrows,
  fzf Ctrl+R selection for editing (not immediate execution).
- Both: repository Git aliases, directory helpers, zoxide, Starship, and mise
  integration when available. Bash and Zsh keep separate history formats/files.
- The Bash installer links `~/.local/bin/ssh2` to the repository helper. Its
  `ssh2.config` is machine-specific: review/configure destinations separately;
  do not treat the source machine's host inventory as a portable requirement.

## 2. Window gaps and animations

Merge these overrides into `~/.config/hypr/looknfeel.lua`, updating existing
matching overrides instead of appending duplicates:

```lua
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 2,
  },
})

hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "slide" })
```

The named curves exist in this version's Omarchy defaults. Check `hyprctl animations`
on the target before using them. Preserve inherited fading and `windowsMove`.
Inner gaps are per window side: `2` produces **4 px between adjacent tiles**;
outer gaps are **2 px**. These are compositor layout units before display scaling.

Validate immediately:

```bash
hyprctl reload
hyprctl configerrors
hyprctl getoption general:gaps_in
hyprctl getoption general:gaps_out
hyprctl animations
```

Require no config errors, both gap values `2` on all sides, and `slide` for
`windowsIn`/`windowsOut`. Open and close tiled windows to check visually.

## 3. Idle timings

Back up `~/.config/omarchy/shell.json` and merge only these two keys, retaining
all other idle settings and the bar/plugin configuration:

```json
{
  "idle": {
    "screensaver": 600,
    "lock": 660
  }
}
```

This is a **partial example**, not a replacement file. Both times are measured
from the start of inactivity: locking occurs one minute after the screensaver,
not eleven minutes after it. The audited defaults were 150 and 300 seconds.

Validate JSON with `python3 -m json.tool ~/.config/omarchy/shell.json >/dev/null`.
The shell hot-reloads this file. Confirm screensaver and lock behavior manually;
do not change suspend or other security settings as part of this step.

## 4. Display scaling (optional, hardware-specific)

The source machine changed these existing locals in `~/.config/hypr/monitors.lua`:

```lua
local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
```

The packaged defaults were GDK scale `2` and monitor scale `"auto"`.
Do not apply 125% to every new machine automatically. Inspect `hyprctl monitors all`,
ask about desired text size, and preserve explicit per-output rules. On mixed-DPI
setups prefer appropriate per-output scales rather than a universal fallback.
After editing, run `hyprctl reload`, `hyprctl configerrors`, and `hyprctl monitors`.
Environment scaling changes may require restarting applications or a new session.

## 5. Theme and optional agent

The current desktop theme is **Stellar** (`stellar`), installed from
<https://github.com/cicorias/omarchy-stellar-theme>. Install and activate this
theme as part of setup. This supersedes the original `tokyo-night` desktop
selection; the repository's Starship prompt remains independent and unchanged.

Check `omarchy theme install --help`, `omarchy theme set --help`, and
`omarchy theme current` on the target machine first. Then run:

```bash
(
  set -e
  if [[ ! -e "$HOME/.config/omarchy/themes/stellar" && ! -L "$HOME/.config/omarchy/themes/stellar" ]]; then
    omarchy theme install https://github.com/cicorias/omarchy-stellar-theme
  fi
  if [[ "$(omarchy theme current)" != "Stellar" ]]; then
    omarchy theme set stellar
  fi
)
```

The installer also activates the theme, so the second check avoids applying it
twice. Do not reinstall over an existing `stellar` directory: inspect its origin
and local changes first, and back it up before any approved replacement (the
installer removes existing theme files). If already installed and active, skip
both mutations. Verify that `omarchy theme current` reports `Stellar`.

Do not copy generated files from `~/.local/state/omarchy/current/`. Install from
the theme repository instead; this follows its default branch rather than a
pinned revision.

`~/.config/omarchy/defaults/agent` contained `pi`. This records a preference only:
agent installation, extensions, models, API credentials, and authentication were
**not audited or exported**. If requested, install/configure the agent using its
current documentation, then select it through Omarchy's default-agent menu.
Do not copy credentials or assume selection means installation is complete.

### Global Pi packages

**Requested addition for Omarchy PCs, not an audited installation:** when setting
up Pi, install `pi-subagents` and `pi-web-access` globally for the destination
user, so they are available across projects.

First confirm `pi` and `npm` are available and inspect `pi list` for existing
**global** entries. A project-local entry does not satisfy this requirement.
Review the packages' upstream source and requirements before installation:
Pi packages execute with the user's full system access. Back up existing
`~/.pi/agent/settings.json` outside the repository and preserve unrelated
settings, package filters, and version pins.

Run only the command for each missing global package, as the normal user:

```bash
pi install npm:pi-subagents
pi install npm:pi-web-access
```

`pi install` defaults to global user settings (`~/.pi/agent/settings.json`);
**do not use `-l` / `--local`, `sudo`, or `npm install -g`** for these Pi packages.
If `PI_CODING_AGENT_DIR` is overridden, confirm the intended agent directory
before installing. Existing global installs should be skipped, not upgraded or
repinned as part of setup.

Verify both appear in the global section of `pi list`, then start a fresh Pi
session and confirm the packages load without errors. Follow each package's
current documentation for any additional configuration or credentials; keep
secrets out of this repository. Record installed versions and any unverified
functionality in the destination setup report.

To roll back packages newly added by this step, use
`pi remove npm:pi-subagents` and/or `pi remove npm:pi-web-access` without `-l`.
Do not remove packages that were already present before setup.

## 6. Zen browser and default-browser associations

Confirmed on the source machine: `zen-browser-bin 1.22b-1`, executable
`/usr/bin/zen-browser`, desktop entry `/usr/share/applications/zen.desktop`.
The default web browser and all four associations below were `zen.desktop`.
Install the current supported version on new machines; the observed version is
not a pin.

After obtaining consent, inspect the target commands:

```bash
omarchy install browser --help
omarchy default browser --help
```

Back up any existing `~/.config/mimeapps.list`,
`~/.local/share/applications/mimeapps.list`, and
`~/.config/environment.d/omarchy-firefox-wayland.conf` before changing them.
Record the previous default browser and the four MIME associations for rollback.
Inspect target-version installer side effects before running it: on 4.0.3-1,
the Zen installer installs `zen-browser-bin` through the AUR helper, configures
Firefox-family distribution policy under `/opt/zen-browser/distribution`, and
writes `MOZ_ENABLE_WAYLAND=1` to the environment file above. Preserve existing
custom policy/environment settings; do not blindly rerun setup over them.

In a visible terminal, install if missing, then select Zen separately:

```bash
omarchy install browser zen
omarchy default browser zen
```

Installation alone does **not** make Zen the default. Use Omarchy's supported
installer rather than downloading an arbitrary binary or copying a browser
profile. Review AUR prompts/build sources. Do not wrap commands that manage their
own privilege elevation in another `sudo` command.

Validate:

```bash
pacman -Q zen-browser-bin
omarchy default browser                         # expected: zen
env -u BROWSER xdg-settings get default-web-browser  # expected: zen.desktop
for type in x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml; do
  printf '%s: ' "$type"
  xdg-mime query default "$type"                # expected: zen.desktop
done
```

If any of those associations remain different, reconcile conflicting desktop
MIME defaults and explicitly set only these associations as needed:

```bash
xdg-mime default zen.desktop x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml
```

Check for a conflicting `BROWSER` environment override in user shell/session
configuration; do not add a hard-coded browser path unnecessarily. New sessions
may be needed for the Wayland environment setting. With user permission, smoke-test
`omarchy launch browser https://example.com` and `xdg-open https://example.com`;
both should open Zen. Verify the desktop browser shortcut as well.

Keep other browsers installed unless removal is separately requested. To roll
back the default, restore the recorded associations/backups or select the previous
browser through `omarchy default browser`. Do not delete Zen profiles. Bookmarks,
passwords, extensions, account sync, and browser-internal preferences are outside
this guide and must be configured separately without exporting private data.

## 7. Zellij with Zsh as the default pane shell

Confirmed on the source machine: Arch package `zellij 0.45.1-1` and an active
(top-level, uncommented) setting in `~/.config/zellij/config.kdl`:

```kdl
default_shell "/usr/bin/zsh"
```

Install missing packages after consent; use current repository versions rather
than pinning the audited version:

```bash
omarchy pkg add zellij zsh
```

Apply the repository Zsh profile from section 1 as well to reproduce shell
behavior, not just the shell executable. Back up the target Zellij config, then
merge the single top-level `default_shell` setting above. Update any existing
active setting rather than appending a duplicate. If the config does not exist,
create its parent directory and a minimal `config.kdl` containing that setting;
there is no need to copy a full generated defaults file. Preserve existing
keybindings, themes, layouts, and plugins.

The normal location is `${XDG_CONFIG_HOME:-$HOME/.config}/zellij/config.kdl`.
Check `ZELLIJ_CONFIG_FILE`, `ZELLIJ_CONFIG_DIR`, and any launcher `--config` or
`--config-dir` arguments before editing: they may select a different file.

Validate using the actual target config path:

```bash
command -v zsh
zellij --version
zellij --config "${XDG_CONFIG_HOME:-$HOME/.config}/zellij/config.kdl" setup --check
```

Start a fresh Zellij session and open a new normal pane. Run
`echo "$ZSH_VERSION"` inside it; expect a nonempty Zsh version. `$SHELL` may still
report Bash because the account/login shell remains Bash. Existing panes keep
their running shells; layouts that explicitly launch commands are not overridden
by `default_shell`. Do not kill existing sessions to apply this preference.

This does not enable automatic Zellij startup in Ghostty or Zsh, change the
account shell, or export session data. Restore the config backup to roll back.
Other Zellij configuration preferences have not been audited for this guide.

## 7a. Login apps: Zen and Ghostty/Zellij

Enable this preference on other Omarchy PCs after installing Zen, Ghostty, and
Zellij (sections 1, 6, and 7). This is Hyprland-login autostart, not system boot
before login and not automatic Zellij startup in every terminal.

Check `command -v zen-browser ghostty zellij` and the target Hyprland version.
Read the current [dispatcher rules](https://wiki.hypr.land/Configuring/Basics/Dispatchers/#executing-with-rules)
and installed Lua API before applying; older `.conf` installations need adaptation.
Back up `~/.config/hypr/autostart.lua`, inspect symlinks, and confirm the main
config loads it. Merge the following block once, preserving unrelated startup
commands. If the block already matches, skip it; otherwise update it in place.
Reconcile other Zen/Zellij autostart entries to avoid duplicate launches.

```lua
-- BEGIN dotfiles login apps
hl.on("hyprland.start", function()
  -- Direct launches let Hyprland track PIDs for these startup-only rules.
  hl.exec_cmd("zen-browser", { workspace = "1 silent" })
  hl.exec_cmd("ghostty --gtk-single-instance=false -e zellij attach --create dotfiles", { workspace = "4 silent" })
end)
-- END dotfiles login apps
```

These rules apply only to the launched processes, not all future Zen or Ghostty
windows. `silent` avoids switching the active workspace. Ghostty uses a separate
process so an existing instance does not bypass PID-based placement. Do not wrap
these launches with `uwsm-app`: systemd indirection can break PID tracking.
Zen placement assumes a fresh browser process at login; forwarding to an already
running browser may not honor the startup rule.

Zellij attaches to or creates the local session named `dotfiles`. Session
resurrection depends on local Zellij state/settings; this does not copy session
data between PCs or preserve processes through reboot. Do not add
`--force-run-commands`: resurrected commands should retain Zellij's confirmation.
The session name does not set a working directory or assume a repository path.

Validate with `luac -p ~/.config/hypr/autostart.lua`, `hyprctl reload`, and
`hyprctl configerrors`. Reload must not launch the apps. On the next normal
login, verify Zen opens on workspace 1 and Ghostty on workspace 4, with Zellij
showing session `dotfiles`. Do not log out or reboot just to validate without
permission. Report the login smoke test separately from parse validation.
To disable, remove only this marked block and reload; running apps remain open.
The shell-only `omarchy-setup.sh` does not deploy desktop settings; apply this
section when following this full setup runbook.

## 8. Omarchy plugins: Omaplug (Plugin Manager)

**Requested addition, not an observed installed customization:** Omaplug was not
present in the local plugin inventory when checked. This guide documents how to
add it on a destination; documenting it does not install it on the source machine.

- Marketplace: <https://plugins.omarchy.org/plugin.html?id=omaplug>
- Upstream: <https://github.com/fross100/omaplug>
- Plugin ID: `omaplug`; display name: **Plugin Manager**; kind: bar widget.
- Reviewed upstream manifest version: `1.4.0` (not a version pin).
- Upstream requirements: Omarchy 4.x, Quickshell, `git`, `jq`, the Omarchy CLI,
  and utilities including `setsid`, `nohup`, `timeout`, and `sed`.

Omaplug provides a graphical interface for discovering installed plugins,
enabling/disabling them, installing from Git, checking/updating third-party
plugins, and removing them. It is a community plugin, not a prerequisite for
Omarchy's built-in `omarchy plugin` commands.

### Check first, then install or enable only if needed

```bash
omarchy plugin list --json
omarchy plugin add --help
```

Inspect the inventory for ID `omaplug`, and check the corresponding directory
under `~/.config/omarchy/plugins/`. If already installed and enabled, skip setup.
If installed but disabled, inspect its source and enable it only after consent.
If a folder exists but is not discovered, investigate validation errors instead
of overwriting it. Preserve local changes and symlinked development installations.

Before installing or enabling, explain that third-party plugins run **unsandboxed
code with the user's permissions**. Review the current source, compatibility,
and marketplace security status; obtain consent. At documentation time, the
marketplace reported a previously reviewed snapshot but newer upstream changes
as `update-unverified`: a listing or schema-validation pass is not a security
guarantee for the current code.

Back up `~/.config/omarchy/shell.json`. Confirm dependencies and install only
missing packages through the supported Omarchy package commands. On a compatible
Omarchy installation, use the marketplace's command **only when absent**:

```bash
omarchy plugin add https://github.com/fross100/omaplug.git --enable
```

For an existing reviewed installation that is merely disabled:

```bash
omarchy plugin enable omaplug
```

Do not use `--yes` to bypass trust prompts. Use Omarchy's plugin manager rather
than manually cloning into packaged directories. Preserve existing bar placement
if already configured; otherwise inspect the resulting widget placement and ask
before moving it. There is no source-machine placement preference to reproduce.
Do not add duplicate widget entries (`allowMultiple` is false).

### Validate and maintain

```bash
omarchy plugin validate "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/omaplug"
omarchy plugin list --json
python3 -m json.tool "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json" >/dev/null
```

Confirm the inventory discovers and enables `omaplug`, then visually verify its
bar icon and that clicking it opens Plugin Manager. Inspect runtime errors if it
is not active; do not treat manifest validation alone as proof that the UI works.
The shell normally hot-reloads plugin/config changes. Restart the shell only if
needed, after explaining the disruption, using `omarchy restart shell`.

Updates are a separate operation, not a setup prerequisite. With explicit consent,
review upstream changes and local modifications before `omarchy plugin update omaplug`.
Do not use Omaplug's bulk-update/remove actions as part of reproducing this guide.
To undo enabling, use `omarchy plugin disable omaplug`. If newly installed and
removal is requested, use `omarchy plugin remove omaplug`; preserve unrelated
plugins and bar settings. Record the installed commit/version and validation
results in the destination setup report.

## 9. Omarchy plugins: OmaSettings

**Requested addition, not currently installed on the audited machine.**

- Marketplace: <https://plugins.omarchy.org/plugin.html?id=io.github.twiking.omasettings>
- Upstream and usage: <https://github.com/twiking/omasettings>
- Plugin ID: `io.github.twiking.omasettings` (not just `omasettings`).
- Reviewed manifest version: `1.3.0` (not pinned); bar widget plus service;
  default bar section: right; multiple widget instances are not supported.

OmaSettings provides a searchable settings window covering Hyprland appearance,
input, displays, keybindings, bar/plugins, and supported application settings.
It opens from its gear icon in the bar or the OmaSettings launcher entry.
Installing it does **not** authorize changing any of those settings.

### Check first and install only if missing

Follow section 8's community-plugin trust, consent, backup, and local-change
preservation rules. Check `omarchy plugin list --json` for the full ID above.
Skip if already installed and enabled; investigate any existing but undiscovered
plugin directory instead of overwriting it. Review current upstream compatibility
and security status before enabling code. The reviewed marketplace listing had
`update-unverified` coverage for changes newer than its verified snapshot.

Upstream requires `jq`; install it only if missing (`omarchy pkg add jq`). Optional
pages use `pactl`, `nmcli`, `bluetoothctl`, `upower`, `powerprofilesctl`,
`timedatectl`, `tmux`, `nvim`, `herdr`, and `xkbcli`. Do not install every optional
tool automatically: upstream says missing tools are reported by the relevant page.

Back up `~/.config/omarchy/shell.json`. After consent, if absent:

```bash
omarchy plugin add https://github.com/twiking/omasettings.git --enable
```

If already installed, reviewed, and merely disabled:

```bash
omarchy plugin enable io.github.twiking.omasettings
```

Keep existing bar layout and plugin settings. Do not remove audio, network, or
other widgets just because OmaSettings offers overlapping controls.

### Important: settings persistence and override precedence

According to upstream, changing Hyprland settings through the UI applies them
live with `hyprctl eval`, persists them in `~/.config/hypr/omasettings.lua`, and
appends a `require` to `hyprland.lua` so this file loads **last**. Those values can
therefore override this guide's earlier gaps, animation, and monitor settings.
Before diagnosing or reapplying settings, inspect both the original user configs
and this generated override file; keep one intentional effective value rather
than repeatedly adding conflicting overrides.

Upstream also documents a marked keybinding block in `bindings.lua` and in-place
individual setting edits for Herdr, tmux, and Neovim. It keeps a first-write
`<file>.omasettings.bak` and validates writes. These safeguards do not replace
agent-created backups or manual verification, and a first-write backup is not
necessarily the state immediately before the latest change.

Installation validation should only open and inspect the UI, not change values
or exercise its bulk reset/undo functions. Future settings changes need consent
and tool-native validation; after Hyprland edits run `hyprctl reload` followed by
`hyprctl configerrors`, even if the UI already applied a live change.

### Validate and roll back

```bash
omarchy plugin validate "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/io.github.twiking.omasettings"
omarchy plugin list --json
python3 -m json.tool "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json" >/dev/null
hyprctl configerrors
```

Confirm discovery/enabling and that the gear icon or launcher opens OmaSettings
without errors. If the target installation uses a different plugin directory,
validate the actual discovered directory instead. Record version/commit and
manual checks. Updates require separate consent and source/local-change review:
`omarchy plugin update io.github.twiking.omasettings`.

Disable with `omarchy plugin disable io.github.twiking.omasettings`. If removal
is requested, use `omarchy plugin remove io.github.twiking.omasettings`; upstream
says its launcher entry is removed too. Do **not** assume uninstalling undoes
settings previously changed through the UI. Review its generated overrides,
`require` line, marked blocks, and affected configs, and restore only intended
changes from backups with consent. Never delete a required Lua file without
reconciling its loader and validating Hyprland afterward.

## 10. Omarchy plugins: Activity Monitor

**Requested addition, not currently installed on the audited machine.**

- Marketplace: <https://plugins.omarchy.org/plugin.html?id=stappmus.activity-monitor>
- Upstream: <https://github.com/stappmus/omarchy-activity-monitor>
- Plugin ID: `stappmus.activity-monitor`; reviewed manifest version: `2.1.1`
  (not pinned).
- Bar widget, default section right, no multiple instances.

Provides CPU, memory, network, disk, GPU, storage, and process information.
Upstream says its native sampler runs while the panel is open, without an extra
background daemon. Hardware metrics depend on driver/kernel support; missing GPU
or energy readings are not necessarily an installation failure.

### Check first and install only if missing

Follow section 8's trust, consent, backup, and local-change preservation rules.
Inspect `omarchy plugin list --json` for `stappmus.activity-monitor`; skip an
already installed/enabled instance. Investigate an existing undiscovered folder
rather than replacing it. Review the current source and native sampler as well
as the manifest: the marketplace listed security coverage as **unverified** at
review time, despite passing compatibility checks.

Back up `~/.config/omarchy/shell.json`. After consent, if absent:

```bash
omarchy plugin add https://github.com/stappmus/omarchy-activity-monitor.git --enable
```

If an existing reviewed installation is merely disabled:

```bash
omarchy plugin enable stappmus.activity-monitor
```

Preserve existing widget placement and settings; do not add duplicate entries.
There are no source-machine custom settings to reproduce. Reviewed manifest
defaults were Balanced sampling, 60 history samples, Celsius, hardware frequencies
shown, compact opening view, and process-power estimates enabled. These are
upstream defaults, not a request to overwrite destination preferences.

The panel invokes an `activity-sampler` executable from its plugin directory.
If the UI reports sampler failures, inspect that file, architecture compatibility,
permissions, and current upstream build instructions. The reviewed Makefile
builds C++17 source using `make` and a C++ compiler. Do not run downloaded code or
rebuild it merely to validate the manifest; obtain consent and review dependencies
before a required build. Record any manual build so future updates are handled
intentionally.

### Optional power helper: do not install by default

Process `~W` values estimate a share of CPU-package energy, **not wall power**.
Upstream describes an optional `omarchy-activity-monitor-power-helper` package
for kernels that restrict RAPL access. Installing the widget does not authorize
installing this helper, elevating privileges, or relaxing kernel permissions.
Leave unavailable metrics alone unless the user requests them. If requested,
review the current helper source, PKGBUILD, and privilege model separately;
use the documented package workflow only after explicit consent.

### Validate and use safely

```bash
omarchy plugin validate "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/stappmus.activity-monitor"
omarchy plugin list --json
python3 -m json.tool "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json" >/dev/null
```

Use the actual discovered plugin path if different. Confirm discovery/enabling,
then click its bar icon and verify that metrics update without runtime errors.
`e` expands the view, Esc collapses, `/` searches processes, and `s` opens settings.
Close the panel afterward. Do not assume schema validation proves the sampler
runs correctly; record the UI test separately.

**Do not click process rows or press `x` during a smoke test:** upstream uses those
for process-closing actions (with confirmation). Do not terminate processes just
to test the widget. Do not alter sampling or temperature preferences without asking.

Updates need separate consent and source/local-change review:
`omarchy plugin update stappmus.activity-monitor`. To undo enabling, use
`omarchy plugin disable stappmus.activity-monitor`; if removal is requested,
use `omarchy plugin remove stappmus.activity-monitor`. A separately installed
power-helper package requires separate review/removal and should not be assumed
to disappear with the plugin. Preserve unrelated widgets and record the installed
version/commit, any optional components, and validation results.

## 11. Omarchy plugins: App Launcher

**Requested addition, not currently installed on the audited machine.**

- Marketplace: <https://plugins.omarchy.org/plugin.html?id=tyrsolution.app-launcher>
- Upstream: <https://github.com/Tyrsolution/omarchy-app-launcher>
- Plugin ID: `tyrsolution.app-launcher`; reviewed manifest version: `0.4.0`
  (not pinned); overlay plus bar widget, default section left, no multiple instances.
- Upstream requirements: Omarchy 4.x with omarchy-shell and Quickshell 0.3+;
  optional configuration wizards also require `gum` and Python 3.

Provides an application/agent grid, searchable system-menu folders, and session
and window toggles. Installing this plugin does not replace the existing launcher
shortcut, install coding agents, or authorize changing defaults or session settings.

### Check first and install only if missing

Follow section 8's trust, consent, backup, and local-change preservation rules.
Check `omarchy plugin list --json` for the exact ID; skip if installed and enabled.
Investigate existing undiscovered folders rather than overwriting them. Review
current source and compatibility before enabling unsandboxed code. At review time
the marketplace marked newer changes `update-unverified` relative to a reviewed
snapshot; compatibility validation is not a security guarantee.

Back up `~/.config/omarchy/shell.json`. After consent, if absent:

```bash
omarchy plugin add https://github.com/Tyrsolution/omarchy-app-launcher.git --enable
```

If an existing reviewed installation is merely disabled:

```bash
omarchy plugin enable tyrsolution.app-launcher
```

Do not copy upstream's `--yes` flag: retain trust prompts. Preserve existing bar
placement and settings; do not create duplicate widget entries.

### Optional shortcut and Setup-menu integration

The plugin's bar button works without adding a keybinding. A shortcut is an
additional preference requiring confirmation, not an automatic replacement of
the stock launcher. Upstream suggests `SUPER + A`, but **check first**:

```bash
omarchy menu keybindings --print
```

If the selected shortcut is already assigned, tell the user its existing action
and obtain approval to replace it (or choose a free combination). Back up
`~/.config/hypr/bindings.lua`; use `hl.unbind` before a replacement binding.
For an approved `SUPER + A` assignment, merge exactly once:

```lua
-- Only if replacing an existing SUPER + A binding, after approval:
-- hl.unbind("SUPER + A")
o.bind("SUPER + A", "App Launcher", "omarchy-shell shell toggle tyrsolution.app-launcher '{}'")
```

Uncomment the unbind only when needed. Validate with `hyprctl reload`, then
`hyprctl configerrors`. Keyboard/IPC opening provides focused-window toggles;
upstream intentionally hides them when opening from the bar to avoid acting on
the wrong window after pointer movement.

Optional Setup-menu wizards are a separate integration. If requested, read the
installed plugin's current `docs/omarchy-menu.jsonc`, back up the user's
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, and merge only its
`setup.applauncher.*` entries while preserving existing entries and resolving
script paths for the actual installation. Do not replace the whole menu file.
Without that integration, do not promise `omarchy menu summon applauncher` works;
the bar button and direct IPC toggle remain available. No source-machine shortcut
or custom Setup-menu preference was found to reproduce.

### Validate without changing settings

```bash
omarchy plugin validate "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/tyrsolution.app-launcher"
omarchy plugin list --json
python3 -m json.tool "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json" >/dev/null
```

Use the actual discovered plugin path if different. With user permission, open:

```bash
omarchy-shell shell toggle tyrsolution.app-launcher '{}'
```

Confirm the overlay and app search work, then close it with Esc (which may first
clear a search or leave a folder). Check the bar button and any approved shortcut.
If runtime loading fails, inspect errors before a consented `omarchy restart shell`;
manifest validation alone does not prove the overlay works.

**Smoke-test cautions:**

- Do not exercise session/window toggles: Window Gaps, Stay Awake, Screensaver,
  and related controls change behavior captured elsewhere in this guide.
- System-menu action rows execute real commands, including shutdown/removal.
- **Remove from launcher** can uninstall the underlying package, not merely hide
  an icon. Do not use it during testing.
- Agent tiles launch actual agent commands. Upstream describes built-in launch
  flags that can bypass permission prompts; review `Agents.js` and any custom
  `agents.json` before using them. Do not launch agents or adopt permission-bypass
  flags as part of setup validation. Setting a default agent is a separate action.

### State, updates, and rollback

Preserve `~/.config/omarchy/app-launcher/agents.json` if present; custom agent
commands require review rather than blind copying. Do not export usage/badge
state from `~/.local/state/omarchy/app-launcher/`. Application wizards create real
files in `~/.local/share/applications/`, visible to other launchers too.

Updates require separate consent and source/local-change review:
`omarchy plugin update tyrsolution.app-launcher`. Disable with
`omarchy plugin disable tyrsolution.app-launcher`, or remove only on request with
`omarchy plugin remove tyrsolution.app-launcher`. Back up local plugin changes
before removal. Upstream says uninstall leaves custom agents, usage state,
user-added keybindings, Setup-menu rows, and created desktop entries behind.
Remove only this plugin's approved shortcut/menu integration if rolling it back,
restore any displaced binding, and validate Hyprland. Preserve user data unless
its deletion is separately requested. Record installed version/commit, optional
integrations, and actual validation results.

## 12. Omarchy plugins: Exposé window overview

**Requested addition, not currently installed on the audited machine.**

- Marketplace: <https://plugins.omarchy.org/plugin.html?id=expose.window-overview>
- Upstream: <https://github.com/kristofferR/omarchy-expose>
- Plugin ID: `expose.window-overview`; reviewed manifest version: `4.1.0`
  (not pinned); overlay, not a bar widget; manifest sets `keepLoaded: true`.
- Requirements: Omarchy Quattro/native shell plugin system and `jq`.

Shows live window previews, search, Quick Look, and workspace/monitor filtering.
Its overview animation is independent of the tiled-window slide animations in
section 2; do not assume those preferences should also change Exposé's animation.

### Check first and install only if missing

Follow section 8's trust, consent, backup, and local-change preservation rules.
Inspect `omarchy plugin list --json` for the exact ID and skip if installed and
enabled. Investigate existing undiscovered folders rather than replacing them.
Review current compatibility and code before enabling an unsandboxed plugin.
The reviewed marketplace snapshot was marked verified at commit
`7a31c5e846a2e12bc1353ba5a0d90d42cc4f2dc8`; recheck the current upstream commit and
status rather than assuming later changes inherit that review.

**Enabling activates a top-left hot corner by default.** Explain this before
installation and ask whether to keep, move, or disable it; inspect other hot-corner
plugins/settings to avoid overlap. Back up `~/.config/omarchy/shell.json`. Install
missing `jq` only if needed (`omarchy pkg add jq`). After consent, if absent:

```bash
omarchy plugin add https://github.com/kristofferR/omarchy-expose.git --enable
```

For an existing reviewed installation that is merely disabled:

```bash
omarchy plugin enable expose.window-overview
```

Preserve existing plugin preferences. If the user declines the hot corner, use
`omarchy-shell expose hotCorner off` after enabling. Other placements can be set
through its Settings panel or current documented IPC. No source-machine custom
Exposé preferences were found to reproduce.

### Optional shortcut and workspace-gesture integration

Do not blindly copy upstream's suggested `SUPER + A`: section 11's App Launcher
suggests the **same chord**. Inspect `omarchy menu keybindings --print` and ask for
a free/approved shortcut. If replacing a binding, explain its previous action,
back up `~/.config/hypr/bindings.lua`, and call `hl.unbind` before the new binding.
For an approved and available `SUPER + A`, the current upstream example is:

```lua
o.bind("SUPER + A", "Exposé", hl.dsp.event("expose.window-overview:toggle"))
```

Use the agreed chord instead if App Launcher or another action owns it. Do not
bind standalone Super or change existing shortcuts without consent. Run
`hyprctl reload` followed by `hyprctl configerrors` after edits.

Upstream optionally supplies `workspace-gesture.lua` to suppress workspace swipes
while the overview is open. This is **not required for installation**. If requested,
read the installed version's README/helper, back up `~/.config/hypr/input.lua`,
and adapt the existing gesture (finger count and scale) rather than appending a
competing gesture. Use upstream's guarded loader with the original workspace
gesture as fallback if the plugin is absent. Validate Hyprland and manually test
swiping both with the overview open and closed. Do not assume four fingers or
scale 0.5 are the destination user's preference.

### Validate safely

```bash
omarchy plugin validate "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/expose.window-overview"
omarchy plugin list --json
python3 -m json.tool "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json" >/dev/null
hyprctl configerrors
```

Use the actual discovered path if different. With user permission:

```bash
omarchy-shell expose open
# Inspect previews/search/Quick Look, then close:
omarchy-shell expose close
```

Check the chosen hot corner/shortcut if configured. Space enlarges/restores a
preview; Esc restores an enlarged view and then closes. **Avoid Shift+Q and
middle-click during tests: they close windows.** Enter or a normal card click
activates a window and, by default, moves the pointer to it.

Live previews may expose sensitive window contents; do not take/share screenshots
without consent. If previews are unavailable, inspect toplevel-export support and
capture policy rather than weakening capture protections automatically. Upstream
says it temporarily raises Hyprland blur while open and restores it on close;
check that normal appearance returns afterward. Manifest validation alone does
not prove capture or the overlay works correctly.

### Updates and rollback

Updates require separate consent and source/local-change review:
`omarchy plugin update expose.window-overview`. Omit upstream's `--yes` so prompts
remain visible. Close the overview before disabling/removing:
`omarchy plugin disable expose.window-overview`, or, on removal request,
`omarchy plugin remove expose.window-overview`.

Remove only this plugin's approved shortcut and restore any displaced binding.
Reconcile optional gesture integration while retaining the user's original
workspace gesture, then reload and validate Hyprland. Upstream stores plugin
settings in its `shell.json` entry, but manual binding/gesture changes still need
explicit rollback. Preserve unrelated configuration and record installed
version/commit, selected hot-corner behavior, optional integrations, and checks.

## 13. Omarchy plugins: AI Usage Bar

**Requested addition; installation and upstream requirements have not been audited.**

- Upstream: <https://github.com/gladimdim/omarchy-ai-usage-bar>

Follow section 8's trust, consent, backup, and local-change preservation rules.
Review the current upstream documentation, manifest, compatibility, and any
credential or usage-data access before installing. Check `omarchy plugin list
--json` against the manifest's plugin ID; skip if already installed and enabled.
If merely disabled, enable the existing reviewed installation using its actual
plugin ID rather than reinstalling it.

Back up `~/.config/omarchy/shell.json`. After consent, install only if absent:

```bash
omarchy plugin add https://github.com/gladimdim/omarchy-ai-usage-bar.git --enable
```

Preserve trust prompts, existing bar placement, and plugin settings. Configure
any required authentication separately; never copy credentials or private usage
data into this repository. Validate the discovered plugin directory with
`omarchy plugin validate`, confirm it is enabled with `omarchy plugin list --json`,
and manually verify the widget works. Record installed version/commit and any
unverified requirements. Updates or removal require separate consent.

## 14. Java and Maven via SDKMAN!

**Installed and verified on the source machine:** SDKMAN 5.23.0, Temurin JDK
25.0.4 LTS (`25.0.4-tem`), and Maven 3.9.16. These are observed versions, not pins.
Fresh Bash/Zsh checks, Java compilation/execution, Maven offline validation, and
an idempotent installer rerun passed. The conflicting mise Java selection was
removed after backing up its config; the previous JDK and other mise tools were
retained.

Follow [Java/Maven setup](java/README.md) after applying the shell profiles in section 1.
Review the script and obtain consent for downloads and missing dependencies.
From the repository root, as the normal user:

```bash
bash omarchy/java/setup.sh
```

This installs SDKMAN only if absent, preserves existing Java/Maven defaults,
and installs SDKMAN's recommended versions for missing tools. For reproducible
project versions, use the guide's explicit version flags. Bash and Zsh load
SDKMAN when present; reconcile conflicting mise Java/Maven settings without
removing mise. Validate in fresh terminals with `sdk current`, `java -version`,
`javac -version`, and `mvn -version`; record the versions and JAVA_HOME.

## Audit boundaries and exclusions

Compared the live Hyprland, Ghostty, Alacritty, Foot, Kitty, Omarchy shell,
and tmux configurations with `/usr/share/omarchy/config/`, and checked shell
loaders, Starship, terminal preference, theme selection, and default-agent state.
A follow-up audit confirmed the Zen package and default-browser/MIME associations;
browser profile contents and installation-policy state were not audited.
A further check confirmed the Zellij package and its explicit Zsh default shell;
other Zellij settings and session state were not exported.

- Hyprland differences were limited to `looknfeel.lua` and `monitors.lua`.
- Ghostty differed only by its Zsh command; font/theme/keybindings matched the
  installed template. Do not freeze those defaults unnecessarily.
- Alacritty, Foot, Kitty's active config, and tmux matched their templates.
- `shell.json` differed only in the two idle timings; no custom bar layout was found.
- No `~/.config/dotfiles/` local overrides were present.
- Extra post-update hooks invited setup of dictation, fingerprint authentication,
  and a default agent. Their contents look like setup invitations, not portable
  personal policy; they were not copied. Presence does not establish completion.
- Voxtype was installed, but its models, shortcuts, and service setup were not
  audited. Fingerprint/PAM setup and other privileged system changes were not audited.
- Git config differed from its template but was intentionally not exported;
  review identity, signing, and credentials locally on each destination.
- Backups, generated theme state, histories, SSH data, and secrets are excluded.
- This is not a full installed-package, system-service, editor, or agent-config
  inventory. Future discoveries should be added after confirming intent.

## Final verification and reporting

Run the repository's isolated tests (see the shell guides for dependencies):

```bash
bash omarchy/tests/test.sh
bash omarchy/tests/zsh-setup.sh
python3 omarchy/tests/history-interactive.py
python3 omarchy/tests/zsh-interactive.py
ghostty +validate-config
hyprctl configerrors
```

In fresh Bash and Ghostty/Zsh sessions, check prompt, aliases, `z`, history keys,
and shell identity (`echo "$ZSH_VERSION"` in Ghostty; `$SHELL` may still be Bash).
Verify the desktop browser shortcut and HTTP/HTTPS links open Zen.
Verify the desktop terminal shortcut opens Ghostty, tile gaps/animations look
right, the display is readable, and idle locking works at the chosen time.

Record target Omarchy version, modified paths, backup locations, tests actually
run, and anything skipped. Reapplying the guide should produce no duplicate
includes/overrides and should not replace unrelated target-machine settings.
