---
name: duck
description: >-
  Explain just the issue on the table, briefly, so the user can make an informed choice — the
  mechanism, what goes wrong, what was ruled out, and the ask stated so it can be answered.
  Assumes they know the product; explains the problem, not the project. Use when the user says
  "duck", "duck it", "duck this", "talk to the duck", "explain it to the duck", "I don't follow",
  "I don't understand what you're asking me", "explain that from scratch", "what do you mean by
  that option", "explain that second one", "what did you just find", "what does that error
  actually mean" or when an answer resolves a different question than the one asked. Ends by
  offering more detail.
---

# Duck — explain the issue, not the project

Forty tool calls deep, the question that comes out ("keep the fallback in `resolveBinding` or hoist
it to the caller?") is answerable only from inside that context — so the decision gets made without
the user.

**They know the product** — what it is for, who uses it, what the repo is. Explain the *issue*: the
mechanism, what breaks, what the choice costs. One clause of placement if the area is obscure; never
a paragraph on the project.

**Half a screen, ~15 lines** — the minimum that makes the choice informed. Every duck closes with:

> Say the word and I'll go deeper on any of this.

Asked for more → expand *that* part only, same rules, still short.

## What is being ducked

| Ducked | They're asking for | Shape |
|---|---|---|
| **A decision** — "what are you asking me?" | the choice, enough to answer | decision |
| **An option** — "what does that one mean?" | one branch opened | option |
| **A finding** — "what did you just tell me?" | a report they can't parse | finding |

Nothing real behind a section → cut it, don't fill it: no padded **Ruled out**, no manufactured
question where there was never a decision.

### Decision

```
**The issue**
<mechanism in a clause, then what it does instead — 2–3 sentences>

**Ruled out**
- <attempt — what happened>                        (max 3; only real ones)

**The choice**
<the options, each with what it costs — one line each>
Recommend: <option>, because <half a line>
```

### Option

They have the decision; open one branch. Cover the others only in how they differ.

```
**What this option does**
<the change it makes, where, in what order — concrete, `file:line`>

**What it costs**
<what it gives up, what it commits us to, what it makes harder>

**Against the others**
- <other option — the one line where it differs>
```

Close by restating the decision in a line; it is still live and still theirs.

### Finding

A report that was unreadable. There may be no decision attached.

```
**What's wrong**
<what it should do, then what it does instead>

**How I know**
<what was observed — command, `file:line`, log — and what is inference>

**What it means**
<who hits it, when, how bad, whether anything is broken right now>
```

Then exactly one ending: **The choice** if a real one falls out, or a single line of what happens
next. Never both, never neither, never an invented question.

## Rules

- **Every name resolves** in a clause — `#412`, `verifyToken`, `--ff-only`, the branch, the error
  string. Unresolved names are where the misunderstanding was living.
- **Mechanism before failure** — a bug stated before its mechanism is noise.
- **A term of art keeps its name, glossed against this task** — "*idempotent* — running the import
  twice leaves the same rows". They need the term to answer you.
- **Observe, don't recall** — re-read the file, re-run the command, re-check the PR; memory may
  brief them on a moved tree.
- **Verified and inferred, separated.**
- **Ruled out, with why**, one line each — else the first suggestion back is a dead end you walked.
- **A live ask has to be answerable**: options, costs, a recommendation — "what do you think?" is
  not one. If the answer wouldn't change what you do next, say what happens next instead; that
  exemption is for something never a decision, not for one you answered yourself.
- **At most one excerpt**, only when the exact wording is what's being decided.
- **Scope is what they pointed at** — past half a screen it's a codebase tour.

## When explaining solves it

The answer sometimes falls out while writing. That changes what goes under **The choice**; it does
not delete the section and does not start the work.

- **Still stop, still ask**, however obvious — the reason you were writing is that the decision
  wasn't yours.
- **A proposal, not a finding** — reasoning, not something you ran. Don't verify it first.
- **Keep the alternatives on the page.**

> Writing this out surfaced `<what>`, which points at `<the answer>`. That's reasoning — I haven't run
> anything against it. Options are still `<a>` and `<b>`; recommend `<the answer>`, because `<half a
> line>`. Your call.

## Follow-ups

- **"Still lost" / "duck it again"** → start from the assumption the first version left unstated.
  Not the same words louder, not longer.
- **"More detail on X"** → that part only.
- **"That's not what I asked"** → they pointed at one option or finding and got the whole decision.
  Re-duck at that scope, in that shape.
- **Answered with a decision** → act on it. No re-briefing.
