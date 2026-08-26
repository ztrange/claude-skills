---
name: low-fuel
description: >-
  Throttle spending and get unfinished work to a durable state before the budget runs out —
  commit, push, draft PR, and only then prose. Use when the user says "we're running out of
  tokens", "low on context", "almost out of budget", "conserve tokens", "throttle", "stop being
  thorough", "make sure this lands", "estamos por quedarnos sin tokens", "ya casi no queda
  contexto", or when the harness warns that context is nearly full mid-task. Trades breadth for
  landing: drops exploration, subagents, option surveys and narration, keeps the verification that
  stops broken work from shipping, and never lets budget pressure become a reason to skip a
  confirmation gate.
---

# Low fuel — land what's in flight, stop paying for the rest

Unfinished work plus an exhausted budget is the one outcome with nothing to show for it. Everything
here optimises for **work that survives the session**, not for finishing the task.

**Invoke it early.** Landing costs something, so the sequence below needs budget to run. Called at
2% remaining it is a eulogy. Called at 20% it works.

Not `/wrap-up` (the work is *finished*; land, clean, archive) and not `/handoff` on its own (a
handoff is expensive prose that assumes you can still afford to write it — here it is step 5, not
step 1).

## The order, cheapest and most durable first

| | Costs | Survives the session |
|---|---|---|
| 1. `git commit` on the branch | ~nothing | yes |
| 2. `git push` | ~nothing | yes, off this machine |
| 3. Draft PR, title says what's incomplete | little | yes, and it's reviewable |
| 4. What's unfinished, in the PR/commit body | little | yes |
| 5. `/handoff` | a lot | yes, if you get there |
| 6. Summary in chat | the most | **no** |

The inversion people get wrong: the chat summary costs the most and survives the least. Agents
running dry typically write it *first*, then hit the limit before pushing — and the work dies on a
machine nobody will open again. Push before prose.

## Stop being magnanimous

| Drop | Why |
|---|---|
| "While I'm here" fixes, adjacent cleanups | Spend on work nobody asked for |
| Re-reading a file already read this session | You have it; re-reading pays twice |
| Re-running a suite that passed and whose code hasn't changed | The result is already known |
| Subagents, workflows, parallel fan-out | Each returns output you then pay again to absorb |
| Option surveys | One recommendation, stated |
| Restating the plan before acting on it | The acting is the plan |
| Narrating tool use | Do it, report what came back |
| Polishing prose | Correct and plain beats well-turned |
| Tests for code this change didn't touch | Not this change's job |
| Opening the next file | Finish the one you're in |

**Scope shrinks to what's already started.** A task that grew during the session gives back its
growth first — the part in flight lands, the rest becomes a line in the PR body.

## What does not get cut

- **The check that stops broken work from landing.** Throttling is cutting breadth, not care. Land
  it verified, or land it *marked* unverified — never land it silently unverified.
- **Saying what you skipped.** A short report that hides a skipped test is worse than no report.
- **The confirmation gate on anything irreversible** — deploy, delete, force-push, merge. Running
  low is not authorization, and "I was about to run out" is not a reason anyone accepts afterwards.
- **A clean final state.** Never end on a dirty tree. If it can't reach working, commit WIP on the
  branch with a message naming what is half-done and what it breaks. Prefer that to `git stash` —
  the stash stack is shared across worktrees and another session can pop yours.
- **The guardrails.** Still no commit in the primary clone, still never on `main`.

## Decide, don't ask

A question costs a round trip and may never be answered — the user may have walked away, and the
budget doesn't pause. Take the reversible option, and put the choice and its alternative in the
commit body where it can be reviewed and undone. This does not extend to the irreversible actions
above; those stop and wait however low the budget is.

## Say it once

Open with one line: throttled, and what that costs this answer.

> Running low, so: landing what's in flight, skipping the integration suite. Details in the PR.

Then stop mentioning it. Repeated "I'm running low" narration is itself spend, and it reads as
hedging rather than as the deliberate degradation it is. One line up front is what keeps terse,
gap-flagged work from being read as your normal quality.
