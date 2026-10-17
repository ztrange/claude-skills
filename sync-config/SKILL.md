---
name: sync-config
description: >-
  Bring the installed Claude Code configuration up to date — pull the repos behind the symlinks in
  `~/.claude/`, report what changed, reconcile the links against what those repos now contain. Use
  when the user says "update my skills", "sync my config", "pull the latest skills", "update the
  installed stuff", "did my skills change", "relink the skills", "what skills do I have", "list my
  skills", "qué skills tengo", "actualiza mis skills". Adds links for new skills, removes only
  dangling ones, always points at the main clone rather than a worktree, says whether a restart is
  needed, and always ends with the full roster — even on a run where nothing changed.
---

# Sync-config — pull the repos, then fix the links

Two things go stale: the *content* behind a link, until its repo is pulled; the *set* of links, until
it is reconciled against what the repos now contain. In that order — a link to a directory that only
exists after the pull can't be made before it.

## 1. Inventory

```bash
ls -l ~/.claude/skills/ ~/.claude/CLAUDE.md
git -C "$(readlink ~/.claude/skills/<name>)" rev-parse --show-toplevel
```

Every entry should be a symlink; resolve each to its target and each target to its repo. They are not
all one repo — a skill can live in the repo of the product it serves. The distinct repos are the
fetch list. A regular file or directory where a symlink was expected is a real difference: report it,
leave it alone.

## 2. Pull — clean and on `main`, or not at all

| Repo state | Action |
|---|---|
| Clean, on `main` | `git pull --ff-only` |
| Dirty, or on a branch | `git fetch` only; report the branch and `git log @{u}.. --oneline`. Never stash, never merge |
| Fetch fails, no upstream | Report the error, carry on with the others |

Record before and after shas — step 3 needs the range. A link into a **worktree** resolves to that
branch, so pulling the main clone changes nothing for it; note those for step 4.

## 3. Say what actually changed

```bash
git log --oneline <before>..<after> -- <linked paths>
```

Three get named explicitly, because each moves behaviour differently:

- **`description:` in a `SKILL.md`** — the trigger surface. Quote what it was and what it now is.
- **`user-prompt/CLAUDE.md`** — global, every project on this machine. Summarize the rules added,
  changed or dropped; a commit count says nothing about how behaviour moved.
- **A new, renamed or deleted skill directory** — feeds step 4.

Nothing changed → say so in one line, then go to section 6 anyway.

## 4. Reconcile — additions are cheap, deletions need a fact

| Case | Action |
|---|---|
| Skill directory in the repo, no link | `ln -s <main-clone>/<skill> ~/.claude/skills/<skill>` |
| Carries an `.on-demand` marker | **Leave unlinked** — see below |
| Link whose target is gone | Search before removing — see below |
| Link into a worktree, target exists | Report it, don't rewrite it. Someone is running a branch live on purpose |
| Link into the main clone, target exists | Leave it; the pull updated the content |
| `deprecated/`, `user-prompt/`, the repo root | Never link — none is a skill |

Link to the **main clone**, never a worktree path: the worktree goes when its branch lands, and the
link dies with it.

**An `.on-demand` marker means no link is the intended state** — a job that happens once, installed
by hand and removed after, so auto-linking would quietly undo a decision. `find <repo> -maxdepth 2
-name .on-demand` lists them.

**A linked `.on-demand` skill is the thing a run has to say out loud**, because nothing breaks when
the link outstays its welcome — it just sits in the loaded set forever, which the marker exists to
prevent. Flag it in its roster row and again in the report, with the command ready:

```bash
rm ~/.claude/skills/<skill>        # done with it?
```

Offer; remove only on an explicit yes, never folded into a sweep. This skill cannot see whether the
one-off job is finished, and a half-done migration looks exactly like one never started.

`~/.claude/CLAUDE.md`, same reconciliation against one target: missing →
`ln -s <main-clone>/user-prompt/CLAUDE.md ~/.claude/CLAUDE.md`; a real file → move it to
`~/.claude/CLAUDE.md.bak`, say so, then link, never overwrite; already that symlink → nothing.

### A dangling link is a question, not a verdict

Dangling proves the *path* is dead, nothing about the skill — usually the repo moved with the skill
inside it. Front-matter `name:` identifies a skill across a move; the directory can be renamed with it.

```bash
find ~/Documents/repos -maxdepth 3 -name SKILL.md -not -path "*/node_modules/*" \
  -exec grep -l "^name: <skill>" {} +
```

| Found | Action |
|---|---|
| One match | Repoint: `rm` the link, recreate against the new path, report old → new |
| Two or more | Don't guess. Report the candidates with their remotes and ask |
| Nothing | Remove the link and say what it pointed at, so a wrong removal is visible |

Fail closed: a reconciliation that would remove every link is a bug — stop and report.

## 5. Report

- Repos pulled with sha ranges (`abc1234..def5678`); repos only fetched, with the reason.
- What changed behaviourally — new or reworded trigger descriptions, global prompt rules, new skills.
  Not a commit dump.
- Links added, removed or flagged, each with its target path.
- **Don't promise a restart you haven't tested.** A new symlink in `~/.claude/skills/` has been picked
  up by the *running* session with no restart (observed 2026-08-12, and again 2026-09 for
  `housekeeping`, `grill-with-docs`, `solve-issues`). Report what you see: in the available-skills
  list → say it's live; absent → say a restart is needed. The one case that genuinely needed one is
  creating `~/.claude/skills/` for the first time. A skill with `disable-model-invocation: true`
  never appears in that list even when loaded, so it cannot be confirmed this way — say that instead
  of guessing.
- Cowork installs a packaged `.skill` bundle and can't follow a symlink. If a skill the user runs
  there changed, say once: rebuild with `python3 package_skill.py <skill-dir> .`.

## 6. Always end with the roster

**Every run, including the ones where nothing changed.** Everything above is a delta, and a delta is
unreadable without the set it applies to — and the question people arrive with is "what am I running
now", not "what moved".

Build it from `~/.claude/skills/`, not from repo contents: the installed set is the claim.

| Skill | What it does | Source |
|---|---|---|
| `merge` | lands a PR on a `main` that may have moved | `claude-skills` |
| `wrap-up` | closes out finished work; fails closed on anything unmerged | `claude-skills` |

Then one line for `~/.claude/CLAUDE.md` — not a skill, but half the install — and the count:
`8 skills + the global prompt`.

- **The gloss comes from each skill's own `description:`, compressed — never from memory.** A roster
  whose wording drifts from the trigger surface teaches the wrong trigger. Read the file.
- **Anomalies go in the row, not a footnote** — `→ worktree`, `dangling`, `not a symlink`,
  `on-demand, still linked`. A broken install rendered as a clean table is the failure this guards.
- **Sort by name.** It is read to find one entry.
- **Say what is deliberately absent**, one line: skills that install with their product repo
  (`ja-changelog`), anything under `deprecated/`, and the `.on-demand` ones **by name** — "available,
  not installed" is a different fact from "does not exist", and they need the name to ask for it.
