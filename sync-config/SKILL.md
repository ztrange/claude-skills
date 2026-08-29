---
name: sync-config
description: >-
  Bring the installed Claude Code configuration up to date — fetch the repos behind the symlinks
  in `~/.claude/`, report what changed, and reconcile the links against what those repos now
  contain. Use when the user says "update my skills", "sync my config", "pull the latest skills",
  "update the installed stuff", "did my skills change", "relink the skills", "what skills do I
  have", "list my skills", "qué skills tengo", "actualiza mis skills". Adds links for new skills
  and removes only dangling ones, always pointing at the main clone rather than a worktree, says
  whether a restart is needed, and always ends with the full roster of installed skills — even on
  a run where nothing changed.
---

# Sync-config — pull the repos, then fix the links

Two different things go stale, and each has its own fix. The *content* behind a symlink goes stale
until its repo is pulled. The *set* of symlinks in `~/.claude/` goes stale until it's reconciled
against what those repos now contain. Do both, in that order — a link to a directory that only
exists after the pull can't be created before it.

## 1. Inventory what's installed

```bash
ls -l ~/.claude/skills/ ~/.claude/CLAUDE.md
```

Every entry should be a symlink. Resolve each one to its target, and each target to the repo that
owns it:

```bash
git -C "$(readlink ~/.claude/skills/<name>)" rev-parse --show-toplevel
```

The targets are not all in one repo — a skill can live in the repo of the product it serves. The
distinct repo list is the fetch list.

A regular file or directory where a symlink was expected is a real difference, not a mistake to
correct silently. Report it and leave it alone.

## 2. Pull each repo — clean and on `main`, or not at all

| Repo state | What to do |
|---|---|
| Clean, on `main` | `git pull --ff-only` |
| Dirty, or on a branch | `git fetch` only, then report the branch and `git log @{u}.. --oneline`. Never stash, never merge |
| Fetch fails, no upstream | Report the error, carry on with the other repos |

Record each repo's before and after sha — step 3 needs the range.

A link pointing into a **worktree** resolves to that branch, not `main`, so pulling the main clone
changes nothing for it. Note those now; step 4 decides what to do about them.

## 3. Say what actually changed

Per repo, scoped to the linked paths:

```bash
git log --oneline <before>..<after> -- <linked paths>
```

Three changes get named explicitly, because each one changes behaviour differently:

- **`description:` in a `SKILL.md` front-matter** — the trigger surface, the text that decides
  when the skill fires. Quote what it was and what it now is.
- **`user-prompt/CLAUDE.md`** — global, every project on the machine. Summarize the rules added,
  changed or dropped; a commit count says nothing about how behaviour moved.
- **A new, renamed, or deleted skill directory** — feeds step 4.

Nothing changed? Say so in one line — then go to section 6 anyway. A no-op sync still owes the
roster, and the roster is what surfaces a link that drifted for reasons no pull would have shown.

## 4. Reconcile the links — additions are cheap, deletions need a fact

Compare the skill directories each repo now contains against `~/.claude/skills/`:

| Case | Action |
|---|---|
| Skill directory in the repo, no link | Create it: `ln -s <main-clone>/<skill> ~/.claude/skills/<skill>` |
| Skill directory carrying an `.on-demand` marker file | **Leave unlinked.** It is installed by hand for one job and removed after — see below |
| Link whose target no longer exists | Search before removing — see below. A dangling link usually means the repo moved, not that the skill died |
| Link into a worktree, target exists | Report it, don't rewrite it. Someone is running a branch live on purpose |
| Link into the main clone, target exists | Leave it. The pull already updated the content |
| `deprecated/`, `user-prompt/`, the repo root | Never link into `skills/` — none of them is a skill |

Link to the **main clone**, never to a worktree path: the worktree is removed when its branch
lands, and the link dies with it.

**An `.on-demand` marker means the absence of a link is the intended state.** Some skills do a job
that happens once — a migration, a one-off setup — and keeping them permanently loaded spends
trigger surface on something that will not come up again. Auto-linking them would quietly undo a
decision, so the marker is checked before the "no link → create it" rule fires. A user who wants
one links it by hand, uses it, and removes the link. `find <repo> -maxdepth 2 -name .on-demand`
lists them.

**A linked `.on-demand` skill is the thing this run has to say out loud.** Removing the link is the
step people forget, because nothing breaks when they don't — the skill just sits in the loaded set
forever, which is the state the marker exists to prevent. So flag it in its roster row, and say it
again in the report with the command ready to run:

```bash
rm ~/.claude/skills/<skill>        # done with it?
```

**Offer to remove it, and remove it only on an explicit yes.** Never fold it into the sweep. This
skill cannot see whether the one-off job is finished — a migration half-done looks exactly like one
never started — and pulling a skill out from under a user mid-task is worse than a link that
outstays its welcome. The reminder is cheap and repeats next run; a wrong removal costs them the
thread they were on.

`~/.claude/CLAUDE.md` is the same reconciliation against a single target:

- Missing → `ln -s <main-clone>/user-prompt/CLAUDE.md ~/.claude/CLAUDE.md`
- A real file → move it to `~/.claude/CLAUDE.md.bak`, say that you did, then link. Never overwrite
  it, never delete it.
- Already that symlink → nothing to do.

### A dangling link is a question, not a verdict

Dangling proves the *path* is dead. It says nothing about the skill, and the common cause is a
repo that was renamed or moved with the skill still inside it. So look for the replacement before
removing anything:

```bash
find ~/Documents/repos -maxdepth 3 -name SKILL.md -not -path "*/node_modules/*" \
  -exec grep -l "^name: <skill>" {} +
```

| What the search finds | Action |
|---|---|
| A `SKILL.md` whose front-matter `name:` matches the dead link | Repoint: `rm` the link, recreate it against the new path. Report the move — old path → new path |
| Two or more matches | Don't guess. Report the candidates with their repo remotes and ask |
| Nothing | Remove the link and say what target it pointed at, so a wrong removal is visible |

Front-matter `name:`, not the directory name, is what identifies a skill across a move — the
directory can be renamed with it.

Fail closed. A reconciliation that would remove every link is a bug, never a clean slate — stop
and report instead.

## 5. Report

- Repos pulled, each with its sha range (`abc1234..def5678`); repos only fetched, with the reason.
- What changed behaviourally — new or reworded trigger descriptions, global prompt rules, new
  skills. Not a commit dump.
- Links added, removed, or flagged, each with its target path.
- **Don't promise a restart you haven't tested.** A new symlink in `~/.claude/skills/` was picked
  up by the *running* session, with no restart — observed 2026-08-12, adding `sync-config` and
  `install-guardrails` mid-session. Report what you see: if a skill you just linked shows up in
  the available-skills list, say it's live; if it doesn't, say a restart is needed. The one case
  that has genuinely needed a restart is creating `~/.claude/skills/` itself for the first time.
- Cowork installs a packaged `.skill` bundle and can't follow a symlink. If a skill the user runs
  in Cowork changed, say once: rebuild with `python3 package_skill.py <skill-dir> .`.

## 6. Always end with the roster

**Every run ends with the full list of installed skills, including the runs where nothing changed.**
Everything above this point is a *delta*, and a delta is unreadable without the set it applies to.
It is also the wrong answer to the question people arrive with — not "what moved" but "what am I
running now". A sync that reports `nothing changed` and stops has answered a question nobody asked.

Build it from `~/.claude/skills/`, not from what the repos contain. The installed set is the claim;
repo contents are how it got there.

| Skill | What it does | Source |
|---|---|---|
| `merge` | lands a PR on a `main` that may have moved | `claude-skills` |
| `wrap-up` | closes out finished work; fails closed on anything unmerged | `claude-skills` |

Then one line for `~/.claude/CLAUDE.md` — not a skill, but half the install — and the count:
`8 skills + the global prompt`. A number is checked against expectation in a second; a bare table
has to be counted.

Four things that make the roster worth printing rather than decorative:

- **The gloss comes from each skill's own `description:`, compressed — never written from
  memory.** Front-matter is the trigger surface: it decides when the skill fires. A roster whose
  wording drifts from it teaches the wrong trigger, which is worse than no roster. Read the file;
  the first dozen lines are enough.
- **Anomalies go in the row, not in a footnote** — `→ worktree`, `dangling`, `not a symlink`,
  `on-demand, still linked`. A broken install rendered as a clean table is the exact failure this
  section guards against, and a footnote is where a reader's eye does not go.
- **Sort by name, not by repo or by recency.** The roster is read to find one entry, and the only
  ordering that helps is the one the reader can predict.
- **Say what is deliberately absent**, in one line: skills that live in a product repo and install
  with it (`ja-changelog`), anything under `deprecated/`, and the `.on-demand` skills — those
  listed by name, since "available, not installed" is a different fact from "does not exist" and
  the user has to know the name to ask for it. Otherwise their absence reads as a gap in the
  install rather than as a decision that was already made.
