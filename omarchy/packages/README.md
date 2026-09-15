# Shared Omarchy apps

These lists define extra apps wanted on every Omarchy PC, not a full export of
one machine's packages. Shared apps include LocalSend and KeePass (`keepass`, from Arch's extra repository).

- `repo.txt`: packages in enabled pacman repositories (including Omarchy).
- `aur.txt`: AUR-only packages, including MEGAsync (`megasync-bin`).

From the repository root on each PC, after pulling the latest changes:

```bash
bash omarchy/packages/setup.sh          # Read-only preview
bash omarchy/packages/setup.sh --apply  # Install missing entries
```

Run `--apply` as your normal user in a visible terminal, after reviewing the
preview and consenting to installation. The script uses `omarchy pkg add` and
`omarchy pkg aur add`; these commands can install without further confirmation.
AUR builds execute third-party code: review sources/PKGBUILDs before applying.

Installed package names are skipped. Reruns only add missing packages; they do
not upgrade installed apps, remove unlisted apps, synchronize versions, change
app defaults, enable autostart, or change firewall rules. Dependencies may be
installed by the package manager. Keep systems updated separately through
Omarchy's normal update workflow; do not use a standalone `pacman -Sy`.

## Add another app

1. Check the exact package name and source on the target Omarchy version.
2. Add one name per line to the appropriate list (`#` comments are supported).
3. Commit and push; pull and run preview/apply on each PC. Agents should read
   these lists as the shared desired state and request consent before applying.

LocalSend currently exists as `localsend` in Omarchy's repository, so it does
not need an AUR entry. If an older PC cannot find it, check that PC's repository
configuration/version rather than silently substituting a different package.
An existing `localsend-bin` installation may conflict: review it manually rather
than authorizing automatic replacement. After installation, launch LocalSend
and test transfers between two PCs on the same network. Network/firewall changes
require separate review and are not performed here.

Removing a line only stops requesting installation; it does not uninstall the app.
The Bash/Zsh profile installers remain configuration-only and independent of this
explicit package step.

Test without installing anything:

```bash
bash omarchy/tests/packages.sh
```
