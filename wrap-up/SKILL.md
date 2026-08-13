---
name: wrap-up
description: >-
  Close out a finished piece of work — land the change, clean the scratch files, remove the git
  worktree, and archive the session. Use when the user says "wrap up", "clean up", "we're done
  here", "close this out", "tidy up and archive", "remove the worktree", "archive this session",
  or "limpia y archiva". Fails closed on anything unmerged, unpushed, or uncommitted: it verifies
  from PR state and the actual tree before deleting, and archiving is always the last step.
---

# Wrap-up — land it, clean it, archive it

Runs in order. **Each step gates the next** — a failure stops the sequence and gets reported, it
never gets skipped past. Nothing here deletes work that isn't provably somewhere else.

## 1. Take stock

Run `/sitrep`. If anything is still in **Remaining** or **Needs you**, stop and show it — closing
out unfinished work is the user's call, not yours.

## 2. Land the change

- Uncommitted changes → commit on the branch (never on `main`), message carrying the why.
- No PR yet → push and open one. Merge only if the user has said to merge.
- CI still running → say so and stop. Don't clean up behind a red or pending build.

## 3. Clean the tree

Delete what was never meant to ship: scratch files, throwaway harnesses, generated bundles, temp
branches, debug logs. `git status --short` must come back clean, and the ignored-file sweep
(`git status --short --ignored`) shouldn't show leftovers you created.

## 4. Remove the worktree — fail closed

Verify **all** of these from observed state before removing anything:

| Check | How | If it fails |
|---|---|---|
| Work is merged | `gh pr view <n> --json state` says `MERGED` | Stop. `git branch --merged` lies under squash merges — never decide from it |
| Nothing uncommitted | `git status --short` empty | Stop and show the files |
| Nothing unpushed | `git log @{u}.. --oneline` empty | Stop and show the commits |
| Not in use elsewhere | `git worktree list`, open PRs | Never touch a worktree another session holds or that has an open PR |

Then remove it:

- `ExitWorktree` only handles a worktree **this session** created with `EnterWorktree`. Anywhere
  else it's a no-op — use `git worktree remove <path>` from the main clone instead.
- `gh pr merge --delete-branch` fails its local cleanup when `main` is checked out in another
  worktree (`fatal: 'main' is already used by worktree at …`). The server-side merge still went
  through — check the PR state, then delete the remote branch with
  `git push origin --delete <branch>`. The local branch survives while its worktree is on it and
  goes away with the worktree.
- Removal failed? Say so with the error. Never fall back to `rm -rf` on a worktree — that leaves
  a stale registration in `.git/worktrees`.

**Never infer what's safe to delete from age, ordering, or a name that looks temporary.** Each
deletion needs a fact behind it. If a sweep would remove everything it looked at, that's a bug —
stop.

## 5. Archive the session — last, and only on a yes

`archive_session` with `session_id: "self"` **ends this conversation** — it stops the session's own
process, not any work of the user's, and cleans up the session's worktree by default. Archived
sessions reopen from the Archived list, so it is not a delete. So:

- It goes last. Anything after it doesn't run.
- Ask first and get an explicit yes. The tool prompts too, but don't lean on that.
- **Describe it as ending the session, never as "stopping the process".** By step 5 there is
  deliberately nothing running — that is what steps 2–4 establish — so unqualified "stops the
  process" reads as though a build, server or job of the user's is about to be killed. The gate
  exists because the call is irreversible *within* the conversation, not because it endangers work.
- **The ask is a confirmation, not a warning.** Closing the session is what the user asked for, so
  don't argue against it, don't lead with what archiving costs, and don't offer "keep it open" as
  the safer choice. Steps 2–4 already established there is nothing to lose; if they hadn't, you
  would have stopped there instead of reaching this step.
- Never archive over unmerged, unpushed, or uncommitted work — steps 2–4 must have passed.
- If the user does this after every merged PR, mention the "Auto-archive on PR close" preference
  in Settings once, then stop suggesting it.

## Report

Close with what landed (PR url, merge sha), what was deleted (worktree path, branches, scratch
files), and anything you left alone and why. Loud about failures, silent about nothing.
