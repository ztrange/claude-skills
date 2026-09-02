---
name: housekeeping
description: >-
  Clean a git repo of what nobody is using — local branches whose PR landed, worktrees whose work
  is provably on `main`, remote-tracking refs for branches gone from origin, dead worktree
  registrations — and report the rest with the fact that keeps it. Use when the user says "clean
  the repo", "housekeeping", "prune branches", "delete stale branches", "remove old worktrees",
  "which worktrees are still in use", "tidy the branches", "gc the repo", "limpia el repo", "borra
  las ramas viejas". Every deletion cites an observed fact — PR state, ancestry of `origin/main`,
  a clean tree, no process inside — never age, name or ordering. `git branch --merged` is not
  consulted because squash merges make it lie. Remote branches, stashes and anything with an open
  PR are never deleted by the sweep; the first two only on an explicit yes, the last never.
---

# Housekeeping — delete only what has a fact behind it

Two tiers, and the line between them is what this skill is for:

- **Sweep** — deleted without asking, because the content is provably somewhere else and the
  deletion is local. A merged PR whose head sha matches the branch tip. Commits that are
  ancestors of `origin/main`. A worktree registration whose directory no longer exists.
- **Needs you** — reported with the ready command, deleted only on an explicit yes. Anything
  outward-facing (a remote branch), anything whose content is nowhere else (a closed-unmerged PR,
  a branch never pushed), anything shared (the stash stack).

Three things are never candidates: `main` (and whatever `origin/HEAD` points at), the primary
clone, and any branch or worktree with an open PR. Not even on a yes — an open PR is someone's
work in review, and this skill cannot see whether they are done.

## 1. Where you are, and refresh the facts

```bash
P=$(git worktree list --porcelain | head -1 | cut -d' ' -f2-)   # the primary clone
git -C "$P" status --short --branch
```

The primary must be on `main` and clean. Off `main` or dirty → report it and stop; fixing that is
`setup-git-guardrail`'s job and a sweep run over an unexpected checkout deletes the wrong things.

Then the two operations that are always safe, because they only discard records of things already
gone:

```bash
git -C "$P" fetch --prune origin        # drops refs/remotes/origin/* for branches deleted on origin
git -C "$P" worktree prune -v           # drops registrations whose directory is already gone
```

Keep both outputs — they are the first lines of the report.

## 2. Inventory — every row carries the fact that classifies it

```bash
git -C "$P" for-each-ref refs/heads \
  --format='%(refname:short)|%(upstream:short)|%(upstream:track)|%(objectname:short)|%(worktreepath)'
gh pr list --state all --limit 500 --json number,state,headRefName,headRefOid,url
git -C "$P" ls-remote --heads origin
```

Match each local branch to PRs by `headRefName`; when a name has several, the highest number is
the one that counts. Then, for every branch that is not `main`:

| Observed fact | Verdict |
|---|---|
| Open PR | **Keep.** Say so; not a candidate on any answer |
| PR `MERGED` and branch tip `==` that PR's `headRefOid` | **Sweep** — `git branch -D`. `-d` refuses here under a squash merge because it cannot see PR state; `-D` is the honest command once the PR has been read |
| PR `MERGED` but tip moved past `headRefOid` | **Needs you** — commits after the merge, nowhere else |
| PR `CLOSED`, not merged | **Needs you** — the content exists only on this branch |
| No PR, tip is an ancestor of `origin/main` (`git merge-base --is-ancestor <tip> origin/main`) | **Sweep** — `git branch -d` |
| No PR, upstream `[gone]`, tip not on `main` | **Needs you** — someone deleted the remote, nothing proves the content landed |
| No PR, never pushed | **Needs you** |
| `gh` unreachable | PR state unknown → only the ancestor-of-`main` rule may delete. Say that the rest was not classified |

A worktree is a branch plus a directory, and the directory adds facts that override the branch's
verdict. For each linked worktree from `git worktree list --porcelain`:

| Observed fact | Verdict |
|---|---|
| `git -C <wt> status --porcelain` not empty | **In use.** Never — dirty means someone is mid-edit |
| `git -C <wt> log @{u}.. --oneline` not empty (or no upstream and tip not on `origin/main`) | **In use.** Never — unpushed commits exist only here |
| A process has its cwd inside it | **In use.** Report the pid and command — a Claude session, a shell, an editor. Nothing gets pulled out from under it |
| Detached HEAD, or `main` checked out here | **Needs you** |
| Tip `==` `origin/main` — a branch with no commits of its own | Nothing to lose, so the branch rule stands — but write `empty` in the row. A worktree created minutes ago and not yet touched looks exactly like this, and the person who made it should see it go |
| Clean, pushed, nobody inside, and the branch verdict is **Sweep** | **Sweep** — `git worktree remove <path>` then the branch |

The in-use check is one observation, not a guess:

```bash
lsof -d cwd -Fpcn 2>/dev/null | awk -v W="<wt>" '/^p/{p=substr($0,2)} /^c/{c=substr($0,2)} /^n/{if (index($0,"n"W)==1) print p, c}'
```

If the harness offers a session list, a session whose cwd is the worktree is the same fact from
the other side — check it too. Ignore this session's own hits when the worktree under inspection
is the one you are running in; then the verdict is **In use** by definition, and it says so.

Also look under the worktree parent directory (`.claude/worktrees/`, or wherever this repo keeps
them) for directories that `git worktree list` does not know about. Those are the leftovers of an
`rm -rf` that never ran `worktree prune`, or of a prune that ran after the directory was moved.
**Needs you** — with `ls -la` of the directory in the report, never a delete.

**Remote branches** on origin whose PR is `MERGED` and that still exist in `ls-remote` are
**Needs you**, always: deleting on origin is outward-facing and shared. Print them with the
command ready:

```bash
git -C "$P" push origin --delete <branch>
```

## 3. The rest of the house

- **Stash.** `git -C "$P" stash list --format='%gd %cr %gs'` — report entries and ages. **Never
  drop one.** The stash stack is shared by every worktree and every session in this repo; an entry
  that looks abandoned may be another session's parked work.
- **Stray files.** `git -C "$P" status --short --ignored` in the primary — list what is there.
  Reproducible build output (a `.gitignore` comment usually says so) is worth naming; deleting
  it is still **Needs you**, because "reproducible" is a claim about a build this skill has not run.
- **Object store.** `git -C "$P" gc --auto` — a no-op unless git's own thresholds are hit, so it
  costs nothing to run every time.

## 4. Gates before anything is deleted

Check all of them against the plan, not against intent:

- A **Sweep** row without a quoted fact does not get swept. Move it to **Needs you**.
- The plan would delete `main`, the primary clone, or a branch with an open PR → **bug, stop.**
- The plan would leave zero local branches, or remove every linked worktree while one of them is
  the one this session runs in → **bug, stop.**
- `git worktree remove` is used without `--force`. It refuses a dirty tree on its own, which is a
  second guard behind step 2, not a redundancy to bypass. If it refuses, the row was misclassified —
  report that, do not force.
- Never `rm -rf` a worktree. It leaves the registration behind in `.git/worktrees` and hides the
  branch's state from the next run.
- Never `git stash pop`, `git stash drop`, or `git stash clear`. Not on a yes either — point the
  user at `git stash list` and let them do it.

## 5. Execute, in this order

1. Worktrees first (`git worktree remove <path>`), because a branch checked out in a worktree
   cannot be deleted.
2. Then local branches (`git branch -d` for ancestors of `main`, `git branch -D` for squash-merged).
3. Remote branches, stray files: only after the user's yes, and only the ones they said yes to.

Quote every command's output. A failure stops the sequence — a refused `worktree remove` or a
`branch -d` that says "not fully merged" means the fact was wrong, and the remaining rows are
re-checked before continuing.

## 6. Report

Three sections, each row with its fact:

- **Removed** — path or branch, and why it was safe: `PR #31 merged, tip 7e0fa4a == PR head`,
  `tip ancestor of origin/main`, `directory gone`.
- **Left alone** — everything in use or with an open PR, and who or what is holding it (`pid 30223
  claude, cwd`).
- **Needs you** — every row with its ready command, one per line, the `[gone]` branches and the
  remote branches grouped so a single yes can cover a group.

A run that finds nothing to remove still prints the inventory: the branch and worktree list with
verdicts is the answer to "what is still in use", which is what people run this to find out.
