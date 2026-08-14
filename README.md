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

- **[`tldr`](tldr/SKILL.md)** — the wall of text minus the wall: bottom line, the few facts that
  change what you do next, the caveat buried in paragraph six, the pending decision. Compresses
  text that already exists and adds nothing to it — unlike `sitrep`, which goes and observes the
  tree.

- **[`wrap-up`](wrap-up/SKILL.md)** — close out finished work: land the change, clean scratch
  files, remove the git worktree, archive the session. Fails closed on anything unmerged,
  unpushed, or uncommitted.

- **[`handoff`](handoff/SKILL.md)** — a paste-ready prompt that resumes the work in a fresh
  context (new session, or after `/clear`): objective, observed state, the next concrete action,
  and the dead ends worth not repeating.

- **[`merge`](merge/SKILL.md)** — land a PR on a `main` that may have moved: detect it locally
  rather than trusting `mergeStateStatus`, rebase, force-push under a *pinned* lease (the bare one
  silently clobbers after any fetch), read the CI result instead of the tick, then merge and clean
  up branch, primary clone and worktree.

- **[`setup-git-guardrail`](setup-git-guardrail/SKILL.md)** — make the rules enforceable instead of
  remembered: a `reference-transaction` hook that refuses commits on `main` even under
  `--no-verify` (the only hook that flag can't skip), scoped so `git pull` still works, plus
  optional GitHub branch protection for the layer that can't be bypassed locally. The one thing no
  git hook can refuse is a branch *switch*, so
  [`scripts/session-drift-check.sh`](setup-git-guardrail/scripts/session-drift-check.sh) runs as a
  Claude Code `SessionStart` hook and reports a primary clone left on the wrong branch — into the
  agent's context, in the session that would otherwise trip over it. Its
  [`scripts/test-guardrail.sh`](setup-git-guardrail/scripts/test-guardrail.sh) builds a throwaway
  repo, installs the hook bodies extracted from `SKILL.md`, and asserts all 50 behaviours —
  including what each refusal *says*, since the message is the whole interface — run it before
  changing the skill.

- **[`sync-config`](sync-config/SKILL.md)** — bring the installed config up to date: pull the repos
  behind the symlinks in `~/.claude/`, report what changed (trigger descriptions, global prompt
  rules, new skills), then reconcile the links — add the missing ones, repoint the ones whose repo
  moved, remove only what has no replacement anywhere, always pointing at the main clone. Ends
  every run with the roster of what is actually installed, including runs where nothing changed —
  a delta is unreadable without the set it applies to, and anomalies (dangling links, links into a
  worktree) are flagged in the row rather than a footnote.

- **`ja-changelog`** — **moved** into its product repo `erliamx/ja-changelog` (under `skill/`), so it
  sits with the app it feeds (DynamoDB + API + site). Since 2026-08-13 it also *installs* with that
  repo — a tracked `.claude/skills/ja-changelog -> ../../skill` symlink — so it is no longer linked
  into `~/.claude/skills/` at all. A frozen snapshot is kept in [`deprecated/`](deprecated/) for
  history; don't edit that copy.

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

A skill can live in any repo; the link just has to point at its `SKILL.md` directory. Edits to the
target are picked up live within a session. Creating `~/.claude/skills/` for the first time
requires restarting Claude Code once so the new directory gets watched.

**A skill that only makes sense inside one project belongs to that project, not to
`~/.claude/skills/`.** Commit the symlink in the project instead — `erliamx/ja-changelog` carries
`.claude/skills/ja-changelog -> ../../skill` in git — and it arrives with the clone, versions with
the code it drives, and needs nothing installed per machine. User-level linking is for the skills
that are useful everywhere, which is what this repo holds.

Link to the **main clone**, not a worktree: the worktree goes away when its branch lands, and the
link dies with it. After that, `/sync-config` keeps the install current — it pulls the repos behind
the links, says what changed, and adds, repoints or prunes links to match.

## Build a bundle for Cowork

Cowork installs a packaged `.skill` file (it can't follow the symlink). Rebuild after changes:

```bash
python3 package_skill.py <skill-dir> .      # writes <skill>.skill (gitignored)
```

Then import the `.skill` in Cowork.
