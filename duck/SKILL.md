---
name: duck
description: >-
  Explain just the issue on the table in plain words, a layer at a time: the first duck is a short
  summary with one concrete example, and each repeat duck on the same issue goes one level deeper
  (mechanism and options, then evidence). Written closer to "explain it to a sharp 15-year-old"
  than a tech spec — examples, exact names, no insider shorthand. Assumes they know the product;
  explains the problem, not the project. Use when the user says "duck", "duck it", "duck this",
  "duck again", "more duck", "talk to the duck", "explain it to the duck", "I don't follow",
  "I don't understand what you're asking me", "explain that from scratch", "what do you mean by
  that option", "explain that second one", "what did you just find", "what does that error
  actually mean" or when an answer resolves a different question than the one asked.
---

# Duck — explain the issue, a layer at a time

Forty tool calls deep, the question that comes out ("keep the fallback in `resolveBinding` or hoist
it to the caller?") is answerable only from inside that context — so the decision gets made without
the user.

**They know the product** — what it is for, who uses it, what the repo is. Explain the *issue*: what
happens, why, what the choice costs. One clause of placement if the area is obscure; never a
paragraph on the project.

## Depth: start small, go deeper only when asked again

The first duck is the **summary**. Each further duck on the *same* issue goes **one level down**.
Count the duck turns already spent on this issue in the conversation; a new issue starts back at 1.

| Duck # | Level | Length | What it adds |
|---|---|---|---|
| 1 | **Summary** | ~5 lines | What's going on, one example, the ask |
| 2 | **How it works** | ~15 lines | The mechanism step by step, what was ruled out, each option with its cost |
| 3+ | **The evidence** | as needed, still one topic | `file:line`, commands run, log lines, verified vs inferred, edge cases |

Each level **builds on** the last — don't repeat what the previous duck already said, add under it.
Past level 3, keep drilling into whatever they point at; never restart from the summary.

Close every duck with one line saying what the next one would add, e.g.:

> Duck again and I'll walk through how `resolveBinding` picks the value, step by step.

At the deepest level with nothing left to add, say so instead.

## How to write it — ELI15, not a spec

Write for a sharp 15-year-old who has never seen this code: smart, willing, but not inside your head.

- **Plain words, short sentences.** "The import runs twice and makes duplicate rows", not "the
  ingestion path lacks idempotency guarantees".
- **Show an example, every time.** A real input and what comes out: "a user named `José` is saved as
  `Jos?`". One concrete case beats three abstract sentences. At level 1, the example *is* most of the
  explanation.
- **Exact terms, not pointers.** Name the actual thing — the function `verifyToken`, the file
  `auth/session.ts`, the error `ECONNRESET`, the flag `--ff-only`, PR "#412 login timeout". Never "the
  fallback", "that thing from earlier", "the second approach", "per the finding above", a bare `#412`.
  If they'd have to scroll up to know what you mean, you've lost them.
- **A term of art keeps its name, with a one-clause gloss tied to this task** — "*idempotent* —
  running the import twice leaves the same rows as running it once". They need the real word to
  answer you; they need the gloss to understand it.
- **Analogies only if they map exactly.** A loose metaphor adds a second thing to decode. Prefer the
  example.
- **What happens before what breaks** — a bug stated before its mechanism is noise.

## What is being ducked

| Ducked | They're asking for |
|---|---|
| **A decision** — "what are you asking me?" | the choice, enough to answer |
| **An option** — "what does that one mean?" | one branch opened |
| **A finding** — "what did you just tell me?" | a report they couldn't parse |

Nothing real behind a section → cut it, don't fill it: no padded **Ruled out**, no manufactured
question where there was never a decision.

### Level 1 — Summary

```
<what's going on, in 1–2 plain sentences>
<one concrete example: this input → this result>
<the ask, if there is one: "Do we A or B? I'd go A, because <half a line>.">
  — or, for a finding with no decision: what happens next, in a line
<one line: what the next duck would add>
```

No headers at this level. Five lines is the target, not the floor.

### Level 2 — How it works

Decision:

```
**What happens**
<the mechanism, step by step, with the example from level 1 walked through it>

**Ruled out**
- <attempt — what happened>                        (max 3; only real ones)

**The choice**
- <option A> — <what it costs, in plain words>
- <option B> — <what it costs>
Recommend: <option>, because <half a line>
```

Option — they have the decision; open one branch. Cover the others only in how they differ:

```
**What this option does**   <the change, where, in what order — with the example>
**What it costs**           <what it gives up, commits us to, makes harder>
**Against the others**      - <other option — the one line where it differs>
```

Close by restating the decision in a line; it is still live and still theirs.

Finding:

```
**What should happen vs what does**   <with the example>
**Why**                               <the mechanism>
**What it means**                     <who hits it, when, how bad, broken right now or not>
```

Then exactly one ending: **The choice** if a real one falls out, or one line of what happens next.

### Level 3+ — The evidence

What the explanation stands on: the `file:line`, the command and its output, the log line, the PR.
**Verified and inferred, separated** — "I ran X and saw Y" vs "this suggests Z". Edge cases and
the less likely failure paths go here, not earlier. At most one excerpt, only when the exact wording
is what matters.

## Rules

- **Observe, don't recall** — re-read the file, re-run the command, re-check the PR; memory may
  brief them on a moved tree.
- **A live ask has to be answerable** at every level: options and a recommendation — "what do you
  think?" is not one. If the answer wouldn't change what you do next, say what happens next instead;
  that exemption is for something never a decision, not for one you answered yourself.
- **Scope is what they pointed at** — depth goes down, never sideways into a codebase tour.

## When explaining solves it

The answer sometimes falls out while writing. That changes the ask; it does not delete it and does
not start the work.

- **Still stop, still ask**, however obvious — the reason you were writing is that the decision
  wasn't yours.
- **A proposal, not a finding** — reasoning, not something you ran. Don't verify it first.
- **Keep the alternatives on the page.**

> Writing this out surfaced `<what>`, which points at `<the answer>`. That's reasoning — I haven't run
> anything against it. Options are still `<a>` and `<b>`; recommend `<the answer>`, because `<half a
> line>`. Your call.

## Follow-ups

- **"Duck again" / "more"** → next level down, same issue.
- **"Still lost"** → *not* deeper: same level, rewritten from the assumption the last one left
  unstated, with a different example. Not the same words louder.
- **"More on X"** → next level, that part only.
- **"That's not what I asked"** → they pointed at one option or finding and got the whole decision.
  Re-duck at that scope, back at level 1.
- **Answered with a decision** → act on it. No re-briefing.
