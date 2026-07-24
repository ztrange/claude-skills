# skills

Git-versioned [Claude Code skills](https://code.claude.com/docs/en/skills). Each top-level folder
is one skill (`<skill>/SKILL.md` + optional `scripts/`, `references/`).

## Skills

_None currently live here._

- **`ja-changelog`** — **moved** into its product repo `erliamx/ja-changelog` (under `skill/`), so it
  sits with the app it feeds (DynamoDB + API + site). A frozen snapshot is kept in
  [`deprecated/`](deprecated/) for history; don't edit that copy.

## Use in Claude Code (live, no rebuild)

Each skill is loaded by symlinking it into `~/.claude/skills/`. The directory name becomes the
slash command:

```bash
mkdir -p ~/.claude/skills
ln -s "$PWD/<skill>" ~/.claude/skills/<skill>
```

A skill can live in any repo — `ja-changelog` now symlinks to `…/erlia/ja-changelog/skill`. Edits to
the target are picked up live within a session. Creating `~/.claude/skills/` for the first time
requires restarting Claude Code once so the new directory gets watched.

## Build a bundle for Cowork

Cowork installs a packaged `.skill` file (it can't follow the symlink). Rebuild after changes:

```bash
python3 package_skill.py <skill-dir> .      # writes <skill>.skill (gitignored)
```

Then import the `.skill` in Cowork.
