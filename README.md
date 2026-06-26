# skills

Git-versioned [Claude Code skills](https://code.claude.com/docs/en/skills). Each top-level folder
is one skill (`<skill>/SKILL.md` + optional `scripts/`, `references/`).

## Skills

- **`ja-changelog/`** — generates client-facing Spanish release changelogs for the Jalisco Alerta
  apps (EDL, SIGEM, Gabinete): pulls the repos, reads published GitHub releases, cross-checks
  ClickUp, and writes value-oriented notes matching the client changelog Google Doc.

## Use in Claude Code (live, no rebuild)

Each skill is loaded by symlinking it into `~/.claude/skills/`. The directory name becomes the
slash command (e.g. `/ja-changelog`):

```bash
mkdir -p ~/.claude/skills
ln -s "$PWD/ja-changelog" ~/.claude/skills/ja-changelog
```

Edits here are picked up live within a Claude Code session. Creating `~/.claude/skills/` for the
first time requires restarting Claude Code once so the new directory gets watched.

## Build a bundle for Cowork

Cowork installs a packaged `.skill` file (it can't follow the symlink). Rebuild after changes:

```bash
python3 package_skill.py ja-changelog .      # writes ja-changelog.skill (gitignored)
```

Then import the `.skill` in Cowork.
