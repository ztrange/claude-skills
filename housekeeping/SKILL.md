---
name: housekeeping
description: >-
  Clean a git repo of what nobody is using — local branches whose PR landed, worktrees provably on
  `main`, dead remote-tracking refs and worktree registrations — and report the rest with the fact
  that keeps it. Use when the user says "clean the repo", "housekeeping", "prune branches", "delete
  stale branches", "remove old worktrees", "which worktrees are still in use", "tidy the branches",
  "gc the repo", "limpia el repo", "borra las ramas viejas". Every deletion cites an observed fact —
  PR state, ancestry of `origin/main`, a clean tree, no process inside — never age, name or
  ordering. `git branch --merged` is never consulted. Remote branches and stashes only on an
  explicit yes; an open PR, never.
---

# Housekeeping — delete only what has a fact behind it

- **Sweep** — delete unasked: content provably elsewhere *and* the deletion local.
- **Needs you** — report with the ready command; delete only on an explicit yes. Outward-facing (a
  remote branch), content nowhere else, or shared (the stash).
- **Never**, even on a yes — `main`, whatever `origin/HEAD` points at, the primary clone, anything
  with an open PR.

## 1. Locate the primary, refresh the facts

```bash
P=$(git worktree list --porcelain | head -1 | cut -d' ' -f2-)   # the primary clone
git -C "$P" status --short --branch
```

Off `main` or dirty → report and stop; repair is `setup-git-guardrail`'s job.

Both of these are always safe, and their output opens the report.

```bash
git -C "$P" fetch --prune origin        # drops refs/remotes/origin/* for branches deleted on origin
git -C "$P" worktree prune -v           # drops registrations whose directory is gone
```

## 2. Inventory — every row carries its classifying fact

```bash
git -C "$P" for-each-ref refs/heads \
  --format='%(refname:short)|%(upstream:short)|%(upstream:track)|%(objectname:short)|%(worktreepath)'
gh pr list --state all --limit 500 --json number,state,headRefName,headRefOid,url
git -C "$P" ls-remote --heads origin
```

Match branches to PRs by `headRefName`; several for one name → highest number wins. Every branch but
`main`:

| Observed fact | Verdict |
|---|---|
| Open PR | **Keep** — not a candidate on any answer |
| PR `MERGED`, tip `==` its `headRefOid` | **Sweep** — `git branch -D`; `-d` refuses under a squash merge, it cannot see PR state |
| PR `MERGED`, tip past `headRefOid` | **Needs you** — post-merge commits, nowhere else |
| PR `CLOSED`, not merged | **Needs you** — content only here |
| No PR, tip an ancestor of `origin/main` (`git merge-base --is-ancestor <tip> origin/main`) | **Sweep** — `git branch -d` |
| No PR, upstream `[gone]`, tip not on `main` | **Needs you** — nothing proves it landed |
| No PR, never pushed | **Needs you** |
| `gh` unreachable | Only the ancestor-of-`main` rule may delete; call the rest unclassified |

A worktree's directory facts override its branch verdict:

| Observed fact | Verdict |
|---|---|
| `git -C <wt> status --porcelain` not empty | **In use** — mid-edit |
| `git -C <wt> log @{u}.. --oneline` not empty (or no upstream and tip not on `origin/main`) | **In use** — unpushed commits only here |
| A process has its cwd inside | **In use** — report pid and command |
| Detached HEAD, or `main` checked out here | **Needs you** |
| Tip `==` `origin/main`, no commits of its own | Branch rule stands, but write `empty` in the row — a worktree created minutes ago looks identical |
| Clean, pushed, nobody inside, branch verdict **Sweep** | **Sweep** — `git worktree remove <path>`, then the branch |

```bash
lsof -d cwd -Fpcn 2>/dev/null | awk -v W="<wt>" '/^p/{p=substr($0,2)} /^c/{c=substr($0,2)} /^n/{if (index($0,"n"W)==1) print p, c}'
```

Check the harness session list too. The worktree you run in is **In use** — say so in its row.

Scan the worktree parent (`.claude/worktrees/`, or wherever this repo keeps them) for directories
`git worktree list` doesn't know — an `rm -rf` with no prune, or a prune after a move. **Needs
you**, with `ls -la`.

**Remote branches** still in `ls-remote` whose PR is `MERGED`: always **Needs you**.

```bash
git -C "$P" push origin --delete <branch>
```

## 3. The rest of the house

- **Stash** — `git -C "$P" stash list --format='%gd %cr %gs'`; report entries and ages. **Never drop
  one**: the stack is shared across worktrees and sessions, so an abandoned-looking entry may be
  another session's parked work.
- **Stray files** — `git -C "$P" status --short --ignored`; list them. Name reproducible build
  output; deleting it is still **Needs you** — this skill hasn't run that build.
- **Object store** — `git -C "$P" gc --auto`, a no-op below git's thresholds; always run it.

## 4. Gates — check the plan, not the intent

- **Sweep** row without a quoted fact → **Needs you**.
- Plan deletes `main`, the primary clone, or a branch with an open PR → **bug, stop.**
- Plan leaves zero local branches, or removes every linked worktree including this session's →
  **bug, stop.**
- Never `git worktree remove --force`: a refusal means the row was misclassified — report it.
- Never `rm -rf` a worktree — it leaves the registration in `.git/worktrees`.
- Never `git stash pop`/`drop`/`clear`, not even on a yes; point at `git stash list`.

## 5. Execute, in this order

1. Worktrees, `git worktree remove <path>` — a branch checked out in one cannot be deleted.
2. Local branches: `-d` for ancestors of `main`, `-D` for squash-merged.
3. Remote branches and stray files: only after the yes, only what it named.

Quote every output. A failure stops the sequence — a refused `worktree remove`, or `branch -d`
saying "not fully merged", means the fact was wrong; re-check the remaining rows.

## 6. Report

- **Removed** — path or branch plus the fact: `PR #31 merged, tip 7e0fa4a == PR head`, `directory
  gone`.
- **Left alone** — in use or open PR, and what holds it (`pid 30223 claude, cwd`).
- **Needs you** — each with its ready command; `[gone]` and remote branches grouped so one yes
  covers a group.

A run that removes nothing still prints the inventory with verdicts.
