# Java and Maven with SDKMAN!

Optional new-PC setup; nothing is installed just by cloning this repository.
SDKMAN! installs a per-user JDK and Maven without changing system Java packages
or Omarchy's packaged files. Official docs: <https://sdkman.io/install> and
<https://sdkman.io/usage>.

## Install

1. Apply the repository [Bash](../README.md) and/or [Zsh](../zsh/README.md)
   profiles first. Both now load SDKMAN when installed; no loader replacement is
   needed if they already point at this repository.
2. Check dependencies (`command -v curl zip unzip`). Install only missing ones
   in a visible terminal, after approval:

   ```bash
   omarchy pkg add curl zip unzip
   ```

3. Review `setup.sh`. It downloads and executes the official SDKMAN installer
   over HTTPS, then downloads Java/Maven through SDKMAN. Run as your normal
   user from the repository root, **not with sudo**:

   ```bash
   bash omarchy/java/setup.sh
   ```

   Fresh installs use SDKMAN's currently recommended Java distribution/version
   and Maven version. These are **not version pins**. Existing working SDKMAN
   defaults are preserved, and reruns skip already configured tools. The script
   does not update SDKMAN, upgrade existing candidates, install OS packages, or
   change shell startup files. Upstream prompts remain interactive. An incomplete
   SDKMAN directory is left untouched for manual investigation.

4. Open a fresh Bash/Zsh terminal and verify:

   ```bash
   sdk version
   sdk current
   command -v java javac mvn
   java -version
   javac -version
   mvn -version
   printf '%s\n' "$JAVA_HOME"
   ```

   Java and Maven should resolve under `~/.sdkman/candidates/`, and Maven should
   report the intended JDK. The installer also checks all three executables.
   Record actual versions in the destination setup report.

## Selecting versions

For a project requiring specific versions, initialize SDKMAN in a fresh shell,
then discover supported identifiers:

```bash
sdk list java
sdk list maven
```

Pass identifiers from those lists (replace the placeholders):

```bash
bash omarchy/java/setup.sh --java <java-identifier> --maven <maven-version>
```

Explicit flags authorize installing and **changing the corresponding default**;
the other tool's existing default remains unchanged. Already installed versions
are reused. Use a project's `.sdkmanrc` and `sdk env` for project-local selection;
this setup does not enable automatic project switching or trust project files.

## Shell integration and mise

Both repository profiles initialize SDKMAN after their normal integrations and
before local overrides. `SDKMAN_DIR` defaults to `$HOME/.sdkman`; for a custom
location, export it before running setup **and before the profile loads** in
future shells. Non-interactive shells are not initialized automatically: scripts
and CI should explicitly source `"$SDKMAN_DIR/bin/sdkman-init.sh"`.

Keep Omarchy's mise installation for other tools. Do not manage the same Java
or Maven selection in both SDKMAN and mise: mise prompt/directory hooks or
project configuration can change PATH/JAVA_HOME again after SDKMAN loads.
Inspect `mise current`, `type -a java mvn`, and project mise config if the fresh
shell verification disagrees. Reconcile only conflicting Java/Maven settings
with consent; do not remove mise or unrelated runtimes.

SDKMAN uses `rcupdate=false` during bootstrap so the upstream installer does not
append duplicate initialization to `.bashrc`, `.zshrc`, or login files. Existing
hand-written SDKMAN initialization should be reconciled when applying the shell
profiles; do not source it twice. SDKMAN configuration, downloaded JDKs, Maven
artifacts (`~/.m2`), and credentials stay outside this repository.

## Rollback and tests

Record `sdk current` before selecting explicit versions. Restore a previous
selection with `sdk default java <previous-id>` / `sdk default maven <previous-version>`.
Removing tools is separate: use `sdk uninstall` only for versions no longer
needed. Do not delete `~/.m2` or SDKMAN data as part of a shell rollback.

Offline tests use a temporary HOME and mock downloads/SDKMAN; no real packages
are installed:

```bash
bash -n omarchy/java/setup.sh
bash omarchy/tests/java-setup.sh
```
