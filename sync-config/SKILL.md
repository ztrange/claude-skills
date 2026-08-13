---
name: sync-config
description: >-
  Bring the installed Claude Code configuration up to date — fetch the repos behind the symlinks
  in `~/.claude/`, report what changed, and reconcile the links against what those repos now
  contain. Use when the user says "update my skills", "sync my config", "pull the latest skills",
  "update the installed stuff", "did my skills change", "relink the skills", "actualiza mis
  skills". Adds links for new skills and removes only dangling ones, always pointing at the main
  clone rather than a worktree, and says whether a restart is needed.
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

Nothing changed? Say so in one line and stop.

## 4. Reconcile the links — additions are cheap, deletions need a fact

Compare the skill directories each repo now contains against `~/.claude/skills/`:

| Case | Action |
|---|---|
| Skill directory in the repo, no link | Create it: `ln -s <main-clone>/<skill> ~/.claude/skills/<skill>` |
| Link whose target no longer exists | Remove the link. Dangling is an observed fact — the rename or deletion already happened upstream |
| Link into a worktree, target exists | Report it, don't rewrite it. Someone is running a branch live on purpose |
| Link into the main clone, target exists | Leave it. The pull already updated the content |
| `deprecated/`, `user-prompt/`, the repo root | Never link into `skills/` — none of them is a skill |

Link to the **main clone**, never to a worktree path: the worktree is removed when its branch
lands, and the link dies with it.

`~/.claude/CLAUDE.md` is the same reconciliation against a single target:

- Missing → `ln -s <main-clone>/user-prompt/CLAUDE.md ~/.claude/CLAUDE.md`
- A real file → move it to `~/.claude/CLAUDE.md.bak`, say that you did, then link. Never overwrite
  it, never delete it.
- Already that symlink → nothing to do.

Fail closed. A reconciliation that would remove every link is a bug, never a clean slate — stop
and report instead. Each removal names the target that no longer exists.

## 5. Report

- Repos pulled, each with its sha range (`abc1234..def5678`); repos only fetched, with the reason.
- What changed behaviourally — new or reworded trigger descriptions, global prompt rules, new
  skills. Not a commit dump.
- Links added, removed, or flagged, each with its target path.
- **Restart or not.** A *new* directory in `~/.claude/skills/` is picked up only after one Claude
  Code restart; edits to an already-linked target are live in the next session. Say which applies.
  Nothing added means no restart.
- Cowork installs a packaged `.skill` bundle and can't follow a symlink. If a skill the user runs
  in Cowork changed, say once: rebuild with `python3 package_skill.py <skill-dir> .`.
