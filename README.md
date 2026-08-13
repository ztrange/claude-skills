# skills

Git-versioned [Claude Code](https://code.claude.com/docs/en/skills) configuration: the skills I
use, plus my global user prompt. Everything here is loaded by symlinking it into `~/.claude/`, so
edits are live — there is no build or install step for day-to-day use.

- Each top-level folder is one skill (`<skill>/SKILL.md` + optional `scripts/`, `references/`).
- `user-prompt/` is the exception: it holds the global user prompt, not a skill.

## Skills

- **[`delegate`](delegate/SKILL.md)** — solve tasks in subagents to keep the main context clean.
  When to delegate vs. do it inline, the five-part subagent prompt with an explicit return
  contract, parallel fan-out and worktree isolation, and how the orchestrator verifies and relays
  results without re-reading everything.

- **[`sitrep`](sitrep/SKILL.md)** — succinct state of the work: what's done, what remains, what
  needs your decision. Three capped sections, grounded in git/PR/CI state rather than recollection.

- **[`wrap-up`](wrap-up/SKILL.md)** — close out finished work: land the change, clean scratch
  files, remove the git worktree, archive the session. Fails closed on anything unmerged,
  unpushed, or uncommitted.

- **[`handoff`](handoff/SKILL.md)** — a paste-ready prompt that resumes the work in a fresh
  context (new session, or after `/clear`): objective, observed state, the next concrete action,
  and the dead ends worth not repeating.

- **[`install-guardrails`](install-guardrails/SKILL.md)** — make the rules enforceable instead of
  remembered: a `reference-transaction` hook that refuses commits on `main` even under
  `--no-verify` (the only hook that flag can't skip), scoped so `git pull` still works, plus
  optional GitHub branch protection for the layer that can't be bypassed locally.

- **[`sync-config`](sync-config/SKILL.md)** — bring the installed config up to date: pull the repos
  behind the symlinks in `~/.claude/`, report what changed (trigger descriptions, global prompt
  rules, new skills), then reconcile the links — add the missing ones, remove only the dangling
  ones, always pointing at the main clone.

- **`ja-changelog`** — **moved** into its product repo `erliamx/ja-changelog` (under `skill/`), so it
  sits with the app it feeds (DynamoDB + API + site). A frozen snapshot is kept in
  [`deprecated/`](deprecated/) for history; don't edit that copy.

## User prompt

[`user-prompt/CLAUDE.md`](user-prompt/CLAUDE.md) is my global user prompt — the standing
instructions Claude Code loads for *every* project on this machine (how to write, git and PR
rules, verification standards, what to do when I push back). It is tracked here so changes to it
are reviewable and revertable like any other code.

Install it the same way as a skill, by symlink:

```bash
mv ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak   # first time only, if a real file is there
ln -s "$PWD/user-prompt/CLAUDE.md" ~/.claude/CLAUDE.md
```

Once symlinked, editing `user-prompt/CLAUDE.md` changes the live prompt immediately — a new
session picks it up, no restart needed. Scope check before adding a rule: this file applies
everywhere, so anything that is only true for one repo belongs in that repo's own `CLAUDE.md`.

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

Link to the **main clone**, not a worktree: the worktree goes away when its branch lands, and the
link dies with it. After that, `/sync-config` keeps the install current — it pulls the repos behind
the links, says what changed, and adds or prunes links to match.

## Build a bundle for Cowork

Cowork installs a packaged `.skill` file (it can't follow the symlink). Rebuild after changes:

```bash
python3 package_skill.py <skill-dir> .      # writes <skill>.skill (gitignored)
```

Then import the `.skill` in Cowork.
