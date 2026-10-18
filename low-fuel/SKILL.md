---
name: low-fuel
description: >-
  Throttle spending and get unfinished work to a durable state before the budget runs out —
  commit, push, draft PR, and only then prose. Use when the user says "we're running out of
  tokens", "low on context", "almost out of budget", "conserve tokens", "throttle", "stop being
  thorough", "make sure this lands" or when the harness warns that context is nearly full
  mid-task. Trades breadth for landing: drops exploration, subagents, option surveys and
  narration, keeps the verification that stops broken work from shipping, and never lets budget
  pressure excuse skipping a confirmation gate.
---

# Low fuel — land what's in flight, stop paying for the rest

Optimise for **work that survives the session**, not for finishing the task.

**Invoke early.** Landing costs budget. At 2% remaining this is a eulogy; at 20% it works.

Not `/wrap-up` (that is *finished* work). Not `/handoff` first — it is expensive prose: step 5 here,
not step 1.

## The order — cheapest and most durable first

| | Costs | Survives |
|---|---|---|
| 1. `git commit` on the branch | ~nothing | yes |
| 2. `git push` | ~nothing | yes, off this machine |
| 3. Draft PR, title says what's incomplete | little | yes, and reviewable |
| 4. What's unfinished, in the PR/commit body | little | yes |
| 5. `/handoff` | a lot | yes, if you get there |
| 6. Summary in chat | the most | **no** |

Push before prose: the chat summary costs most and survives least.

## Drop

| Drop | Why |
|---|---|
| "While I'm here" fixes, adjacent cleanups | Nobody asked |
| Re-reading a file already read this session | You have it |
| Re-running a suite that passed on unchanged code | Result is known |
| Subagents, workflows, fan-out | Each returns output you pay again to absorb |
| Option surveys | One recommendation, stated |
| Tests for code this change didn't touch | Not this change's job |
| Opening the next file | Finish the one you're in |

**Scope shrinks to what's already started.** The part in flight lands; the rest becomes a line in the
PR body.

## Not cut

- **The check that stops broken work landing.** Land it verified, or land it *marked* unverified —
  never silently unverified.
- **Saying what you skipped.**
- **The confirmation gate on anything irreversible** — deploy, delete, force-push, merge. Running low
  is not authorization.
- **A clean final state.** Never end on a dirty tree: WIP-commit on the branch naming what is
  half-done and what it breaks. Not `git stash` — the stack is shared across worktrees.

## Decide, don't ask

A question costs a round trip and may never be answered. Take the reversible option; the choice and
its alternative go in the commit body. Irreversible actions above still stop and wait.

## Say it once

One line up front: throttled, and what it costs this answer.

> Running low, so: landing what's in flight, skipping the integration suite. Details in the PR.

Then stop — repeating it is spend, and reads as hedging.
