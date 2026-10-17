---
name: wrap-up
description: >-
  Close out a finished piece of work — land the change, clean the scratch files, remove the git
  worktree, archive the session. Use when the user says "wrap up", "clean up", "we're done here",
  "close this out", "tidy up and archive", "remove the worktree", "archive this session", or "limpia
  y archiva". Fails closed on anything unmerged, unpushed or uncommitted: it verifies from PR state
  and the actual tree before deleting, and archiving is always the last step.
---

# Wrap-up — land it, clean it, archive it

In order. **Each step gates the next** — a failure stops the sequence and gets reported.

## 1. Take stock

Run `/sitrep`. Anything still in **Remaining** or **Needs you** → stop and show it.

**Needs you** means questions the *user's work* left behind, not ones about this run's own mechanics:
"confirm removing the worktree" is not one — steps 2–4 settle it.

## 2. Land

- Uncommitted → commit on the branch, message carrying the why.
- No PR → push and open one. Merge only if the user said to.
- CI running or red → say so and stop.

## 3. Clean

Delete what was never meant to ship: scratch files, throwaway harnesses, generated bundles, temp
branches, debug logs. End with `git status --short` clean and `git status --short --ignored` free of
leftovers you created.

## 4. Remove the worktree — fail closed

All four, from observed state, before removing anything:

| Check | How | If it fails |
|---|---|---|
| Merged, **or** never diverged | `gh pr view <n> --json state` is `MERGED`; **or** no PR, no upstream, and `git log main..HEAD --oneline` empty | Stop. Never decide from `git branch --merged` |
| Nothing uncommitted | `git status --short` empty | Stop, show the files |
| Nothing unpushed | `git log @{u}.. --oneline` empty | Stop, show the commits |
| Not in use elsewhere | `git worktree list`, open PRs | Never touch a worktree another session holds or that has an open PR |

"Never diverged" proves there was nothing to merge, not a weaker merged — the other three rows
still apply.

Then:

- `ExitWorktree` only handles a worktree **this session** created with `EnterWorktree`; elsewhere a
  no-op — use `git worktree remove <path>` from the main clone.
- `gh pr merge --delete-branch` fails its local step when the primary clone holds `main`
  (`fatal: 'main' is already used by worktree at …`); the server-side merge still landed. Check PR
  state, then `git push origin --delete <branch>`. The local branch goes with the worktree.
- Removal failed → report the error. Never `rm -rf` a worktree: it leaves a stale registration in
  `.git/worktrees`.

**Never infer what's safe to delete from age, ordering, or a temporary-looking name.** A sweep that
would remove everything it looked at is a bug — stop.

## 5. Archive — last, and without asking again

`archive_session` with `session_id: "self"` ends this conversation and cleans up the session's
worktree by default. Reversible — archived sessions reopen from the Archived list.

- **Goes last.** Nothing after it runs — send the report *before* the call.
- **Don't ask.** Invoking `/wrap-up` is the agreement, steps 2–4 make it safe, and `archive_session`
  prompts on its own.
- **Don't risk-manage it.** No warning about what archiving costs, no "keep it open" as the safer
  choice, and never an unqualified "stops the process" — nothing is running by step 5, so that reads
  as though a build were about to be killed.
- Never archive over unmerged, unpushed or uncommitted work.
- Wrapping up after every merged PR → mention the "Auto-archive on PR close" preference in Settings
  once, then stop.

## Report

What landed (PR url, merge sha), what was deleted (worktree path, branches, scratch files), what you
left alone and why.
