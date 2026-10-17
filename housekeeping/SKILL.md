---
name: housekeeping
description: >-
  Clean a git repo of what nobody is using — local branches whose PR landed, worktrees whose work is
  provably on `main`, remote-tracking refs for branches gone from origin, dead worktree
  registrations — and report the rest with the fact that keeps it. Use when the user says "clean the
  repo", "housekeeping", "prune branches", "delete stale branches", "remove old worktrees", "which
  worktrees are still in use", "tidy the branches", "gc the repo", "limpia el repo", "borra las ramas
  viejas". Every deletion cites an observed fact — PR state, ancestry of `origin/main`, a clean tree,
  no process inside — never age, name or ordering. `git branch --merged` is never consulted. Remote
  branches and stashes go only on an explicit yes; anything with an open PR, never.
---

# Housekeeping — delete only what has a fact behind it

- **Sweep** — deleted without asking: the content is provably somewhere else *and* the deletion is
  local. A merged PR whose head sha matches the branch tip; commits that are ancestors of
  `origin/main`; a worktree registration whose directory is gone.
- **Needs you** — reported with the ready command, deleted only on an explicit yes. Outward-facing (a
  remote branch), content nowhere else (closed-unmerged PR, never pushed), or shared (the stash stack).

Never candidates, not even on a yes: `main` (and whatever `origin/HEAD` points at), the primary
clone, and any branch or worktree with an open PR.

## 1. Where you are, and refresh the facts

```bash
P=$(git worktree list --porcelain | head -1 | cut -d' ' -f2-)   # the primary clone
git -C "$P" status --short --branch
```

Primary must be on `main` and clean. Off `main` or dirty → report and stop; a sweep over an
unexpected checkout deletes the wrong things (and fixing it is `setup-git-guardrail`'s job).

Then the two always-safe operations — they only discard records of things already gone. Keep both
outputs; they are the first lines of the report.

```bash
git -C "$P" fetch --prune origin        # drops refs/remotes/origin/* for branches deleted on origin
git -C "$P" worktree prune -v           # drops registrations whose directory is gone
```

## 2. Inventory — every row carries the fact that classifies it

```bash
git -C "$P" for-each-ref refs/heads \
  --format='%(refname:short)|%(upstream:short)|%(upstream:track)|%(objectname:short)|%(worktreepath)'
gh pr list --state all --limit 500 --json number,state,headRefName,headRefOid,url
git -C "$P" ls-remote --heads origin
```

Match branches to PRs by `headRefName`; several for one name → the highest number counts. For every
branch that is not `main`:

| Observed fact | Verdict |
|---|---|
| Open PR | **Keep**, and say so. Not a candidate on any answer |
| PR `MERGED`, tip `==` its `headRefOid` | **Sweep** — `git branch -D`. `-d` refuses under a squash merge because it cannot see PR state |
| PR `MERGED`, tip moved past `headRefOid` | **Needs you** — commits after the merge, nowhere else |
| PR `CLOSED`, not merged | **Needs you** — content exists only here |
| No PR, tip is an ancestor of `origin/main` (`git merge-base --is-ancestor <tip> origin/main`) | **Sweep** — `git branch -d` |
| No PR, upstream `[gone]`, tip not on `main` | **Needs you** — nothing proves the content landed |
| No PR, never pushed | **Needs you** |
| `gh` unreachable | Only the ancestor-of-`main` rule may delete; say the rest was unclassified |

A worktree is a branch plus a directory, and the directory's facts override the branch verdict:

| Observed fact | Verdict |
|---|---|
| `git -C <wt> status --porcelain` not empty | **In use** — someone is mid-edit |
| `git -C <wt> log @{u}.. --oneline` not empty (or no upstream and tip not on `origin/main`) | **In use** — unpushed commits exist only here |
| A process has its cwd inside it | **In use** — report pid and command |
| Detached HEAD, or `main` checked out here | **Needs you** |
| Tip `==` `origin/main`, no commits of its own | Branch rule stands, but write `empty` in the row — a worktree created minutes ago looks identical, and its owner should see it go |
| Clean, pushed, nobody inside, branch verdict **Sweep** | **Sweep** — `git worktree remove <path>`, then the branch |

```bash
lsof -d cwd -Fpcn 2>/dev/null | awk -v W="<wt>" '/^p/{p=substr($0,2)} /^c/{c=substr($0,2)} /^n/{if (index($0,"n"W)==1) print p, c}'
```

A harness session list is the same fact from the other side — check it too. The worktree you are
running in is **In use** by definition, and the row says so.

Also look under the worktree parent (`.claude/worktrees/`, or wherever this repo keeps them) for
directories `git worktree list` doesn't know — leftovers of an `rm -rf` with no prune, or a prune
after the directory moved. **Needs you**, with `ls -la` in the report.

**Remote branches** still in `ls-remote` whose PR is `MERGED` are always **Needs you**:

```bash
git -C "$P" push origin --delete <branch>
```

## 3. The rest of the house

- **Stash** — `git -C "$P" stash list --format='%gd %cr %gs'`, report entries and ages. **Never drop
  one**: the stack is shared by every worktree and session here, and an abandoned-looking entry may
  be another session's parked work.
- **Stray files** — `git -C "$P" status --short --ignored`, list what's there. Reproducible build
  output is worth naming; deleting it is still **Needs you**, since "reproducible" is a claim about a
  build this skill hasn't run.
- **Object store** — `git -C "$P" gc --auto`, a no-op below git's own thresholds, so run it always.

## 4. Gates — check against the plan, not the intent

- A **Sweep** row without a quoted fact → move it to **Needs you**.
- The plan would delete `main`, the primary clone, or a branch with an open PR → **bug, stop.**
- The plan would leave zero local branches, or remove every linked worktree including this session's
  → **bug, stop.**
- `git worktree remove` without `--force`. It refuses a dirty tree on its own; a refusal means the
  row was misclassified — report it, don't force.
- Never `rm -rf` a worktree: it leaves the registration in `.git/worktrees`.
- Never `git stash pop`/`drop`/`clear`. Not on a yes either — point at `git stash list`.

## 5. Execute, in this order

1. Worktrees (`git worktree remove <path>`) — a branch checked out in one cannot be deleted.
2. Local branches: `-d` for ancestors of `main`, `-D` for squash-merged.
3. Remote branches and stray files: only after the yes, only what it named.

Quote every command's output. A failure stops the sequence — a refused `worktree remove`, or a
`branch -d` saying "not fully merged", means the fact was wrong; re-check the remaining rows.

## 6. Report

- **Removed** — path or branch, and why it was safe: `PR #31 merged, tip 7e0fa4a == PR head`, `tip
  ancestor of origin/main`, `directory gone`.
- **Left alone** — in use or open PR, and what holds it (`pid 30223 claude, cwd`).
- **Needs you** — each with its ready command, `[gone]` and remote branches grouped so one yes
  covers a group.

A run that removes nothing still prints the inventory with verdicts: that is the answer to "what is
still in use", which is what people run this to find out.
