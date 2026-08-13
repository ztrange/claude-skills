# Working in this repo

Git-versioned Claude Code configuration. Two kinds of thing live here, and they are loaded the
same way — by symlink out of `~/.claude/`, so **every file here is live config, not a draft**. An
edit lands in the next session with no build step.

## Layout

| Path | What it is |
|---|---|
| `<skill>/SKILL.md` | One skill per top-level folder, plus optional `scripts/`, `references/` |
| `user-prompt/CLAUDE.md` | The global user prompt, symlinked to `~/.claude/CLAUDE.md` |
| `deprecated/` | Frozen snapshots of retired skills. Read-only — never edit |
| `package_skill.py` | Builds a `.skill` bundle for Cowork (gitignored output) |

## Rules

- **`user-prompt/CLAUDE.md` is global.** It applies to every project on this machine. A rule that
  is only true for one repo belongs in that repo's `CLAUDE.md`, not here. Changing it changes how
  Claude behaves everywhere, so it goes through a branch and PR like anything else.
- **This file (`/CLAUDE.md`) is repo-scoped** and stacks *on top of* the global prompt — don't
  duplicate global rules here, and don't contradict them silently. If a repo rule has to override
  a global one, say so explicitly and say why.
- **Skill front-matter is the trigger surface.** The `description` in `SKILL.md` is what decides
  whether a skill fires. Editing the body without editing the description changes behaviour only
  after the skill is already invoked.
- **README and behaviour change together.** A new skill, a renamed one, or a changed install path
  updates `README.md` in the same commit.
- **Don't edit `deprecated/`.** It exists for history. The live copy is elsewhere (e.g.
  `ja-changelog` now lives in `erliamx/ja-changelog` under `skill/`).

## Verifying a change

There are no tests. Verification is behavioural:

- Symlinks resolve: `ls -l ~/.claude/skills/ ~/.claude/CLAUDE.md`
- The skill/prompt actually loads in a fresh session (a new directory under `~/.claude/skills/`
  needs one Claude Code restart; edits to an already-linked target do not).
- If a change is to `user-prompt/CLAUDE.md`, exercise the rule it adds rather than asserting it
  reads well.
