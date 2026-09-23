# Shared agent skills

The tracked skills in this directory are installed for Pi, Codex, and Claude.
Currently this includes `unslop`. Review each `SKILL.md` and any files beside it
before installation: agents may follow instructions in these files.

From the repository root, run as your normal user:

```bash
bash omarchy/skills/setup.sh
bash omarchy/skills/setup.sh --apply
```

The first command previews changes. The second creates links at
`~/.pi/agent/skills/<name>`, `~/.codex/skills/<name>`, and
`~/.claude/skills/<name>`. The Pi directory follows `PI_CODING_AGENT_DIR` if set;
the Codex directory follows `CODEX_HOME` if set. The installer does not install
agents, change settings or credentials, or replace existing files. If a skill
already exists at a destination and is not the expected link, it stops before
making any changes. Inspect and move that entry aside yourself before rerunning.
Identical links are skipped. Keep this repository in place so the links work.
After moving the repository, remove the old links and rerun the installer.

To add a skill, put a directory named for the skill under `omarchy/skills/`
with a `SKILL.md` containing matching `name` and `description` frontmatter.
Keep its supporting files in that directory. The installer discovers every
skill directory automatically and links the whole directory to each agent.
It never removes skills when you delete one from the repository. Remove obsolete
links yourself after checking they still point here. Restart agent sessions to
load newly added skills.

Test the installer without touching your agent configuration:

```bash
bash omarchy/tests/skills-setup.sh
```
