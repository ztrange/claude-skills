---
name: duck
description: >-
  Explain just the issue on the table, briefly, so the user can make an informed choice — the
  mechanism, what goes wrong, what was ruled out, and the ask stated so it can be answered. Assumes
  they know the product; explains the problem, not the project. Use when the user says "duck", "duck
  it", "duck this", "talk to the duck", "explain it to the duck", "I don't follow", "I don't
  understand what you're asking me", "explain that from scratch", "what do you mean by that option",
  "explain that second one", "what did you just find", "what does that error actually mean",
  "explícamelo desde cero", "no entiendo qué me estás pidiendo", or when an answer comes back that
  resolves a different question than the one asked. Ends by offering more detail on request.
---

# Duck — explain the issue, not the project

The user is the duck, and the duck answers back — but only if the explanation is complete enough to
be advised on.

The failure it fixes: forty tool calls deep, everything has a name, and the question that comes out
("keep the fallback in `resolveBinding` or hoist it to the caller?") is answerable only from inside
that context. They have been doing something else, so they answer a different question or tell you to
just decide — and a decision that needed them got made without them.

## Two rules above the rest

**They know the product.** What it is for, who uses it, what the repo is — all assumed. Explain the
*issue*: the mechanism around it, what breaks, what the choice costs. One short clause placing it in
the system is fine when the area is genuinely obscure; a paragraph introducing the project is not.

**Be brief.** Half a screen, ~15 lines. The whole explanation is the minimum that makes the choice
informed, and the user pulls more if they want it:

> Say the word and I'll go deeper on any of this.

That line closes every duck. Asked for more → expand *that* part only, same rules, still short.

## What is being ducked

| Ducked | They're asking for | Shape |
|---|---|---|
| **A decision** — "what are you asking me?" | the choice, enough to answer | decision |
| **An option** — "what does that one mean?" | one branch opened | option |
| **A finding** — "what did you just tell me?" | a report they can't parse | finding |

A section with nothing real behind it gets cut, not filled — a padded **Ruled out** on something found
on the first read, or a manufactured question on something that was never a decision, is how this goes
wrong.

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

They have the decision and want one branch opened. Don't re-litigate it; cover the others only in how
they differ.

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

Something was reported and the report was unreadable. There may be no decision attached.

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

- **Every name resolves** — `#412`, `verifyToken`, `--ff-only`, the branch, the error string — in a
  clause, not a sentence. Unresolved names are where the misunderstanding was living.
- **Mechanism before failure.** A bug described before its mechanism is noise.
- **A term of art keeps its name and gets a gloss anchored to this task** — "*idempotent* — running
  the import twice leaves the same rows". They need that term to answer you.
- **Observe, don't recall.** Re-read the file, re-run the command, re-check the PR. Explaining from
  memory reproduces the context that already lost them, and may brief them on a moved tree.
- **Mark the guesses.** Verified and inferred, separated.
- **Say what you ruled out, and why**, one line each — else the first suggestion back is the dead end
  you already walked.
- **A live ask has to be answerable**: options, costs, a recommendation. "What do you think?" is not
  one. If the answer wouldn't change what you do next it isn't a decision — say what happens next
  instead. That exemption is for something never a decision, not for one you answered yourself.
- **At most one excerpt**, and only when the exact wording is what's being decided.
- **Scope is what they pointed at.** Past half a screen you've started giving a codebase tour.

## When explaining solves it

The answer sometimes falls out while writing. That changes what goes under **The choice**; it does not
delete the section and it does not start the work.

- **Still stop, still ask**, even when it looks obvious. Finding it while explaining doesn't make the
  decision yours — the reason you were writing is that it wasn't.
- **It's a proposal, not a finding** — reasoning, not something you ran. Don't go verify it first;
  that is doing the work before the decision.
- **Keep the alternatives on the page.**

> Writing this out surfaced `<what>`, which points at `<the answer>`. That's reasoning — I haven't run
> anything against it. Options are still `<a>` and `<b>`; recommend `<the answer>`, because `<half a
> line>`. Your call.

## Follow-ups

- **"Still lost" / "duck it again"** → find the assumption the first version leaned on without stating
  and start there. Not the same words louder, and not longer by default.
- **"More detail on X"** → that part only.
- **"That's not what I asked"** → they pointed at one option or finding and got the whole decision.
  Re-duck at that scope, in that shape.
- **Answered with a decision** → act on it. No re-briefing.
