---
name: weigh
description: >-
  Weigh a decision or idea from both sides before anyone commits: the strongest honest case for
  doing it, the strongest case against (including "do nothing" and a cheaper alternative), the one
  or two questions it really hinges on, and a lean with what would flip it. Written in duck's plain
  style — examples, exact names — and a layer at a time: short first, deeper each time it is asked
  again. Use when the user says "weigh", "weigh it", "weigh this", "weigh again", "pros and cons",
  "should we do X", "is this a good idea", "argue both sides", "play devil's advocate", "challenge
  this", "convince me", "talk me out of it", "steelman it", "what's the case against". Not for
  interviewing the user about a plan (that is `grilling`) or explaining a confusing issue (`duck`).
---

# Weigh — the case for, the case against, and what it hinges on

An idea that gets only its case *for* gets done because nobody argued. One that gets only
objections dies for the same reason. Weigh gives both sides the same effort, then says which way it
leans and why — and leaves the call with the user.

**Not grilling, not duck.** `grilling` asks *the user* questions until the plan is clear. `duck`
explains an issue they don't follow. Weigh argues the decision itself, both ways.

## Before arguing

- **Pin the decision in one sentence**: what changes if the answer is yes. "Move the nightly import
  from cron on the EC2 box to a Lambda on a schedule." If two readings mean different decisions,
  ask which — that's the one question allowed before weighing.
- **Observe, don't recall.** Look at the code, the config, the bill, the PR before arguing about it.
  A pro or con built on a fact you didn't check is a guess; label it as one.
- **"Do nothing" is always an option**, and usually the strongest rival. Name it, plus the cheapest
  version of the idea if there is one.

## How to write it

Use `duck`'s writing rules: plain words, short sentences, a concrete example per point, exact names
(`importOrders`, `t3.small`, PR "#412 login timeout") — never "the other approach" or "that thing
earlier". A term of art keeps its name with a one-clause gloss tied to this decision — "*one-way
door* — once customers' URLs change, we can't take it back without breaking their bookmarks".

- **Steelman both sides.** Each side is argued as its smartest believer would argue it. A weak point
  on either side is cut, not kept as filler — two strong reasons beat five padded ones.
- **Equal effort.** If you already lean, argue the other side *harder*, not softer.
- **Every point says what it gets or costs, concretely**: time, money, risk, who it hits, with a
  number where one exists and was measured. "Saves ~$40/month (current EC2 bill: $41.20)" beats
  "cheaper".
- **Verified vs inferred, separated** — "I checked X" vs "I expect Y".
- **Reversibility counts.** Say whether it's easy to undo; a hard-to-undo yes needs a stronger case.

## Depth: short first, deeper when asked again

Same ladder as `duck`. Count the weigh turns spent on this decision; a new decision starts at 1.

| Weigh # | What you get |
|---|---|
| 1 | The decision, top 2–3 reasons each way, the crux, the lean — ~15 lines |
| 2 | Each side opened up: weaker-but-real points, the alternatives in full, hidden costs, what each side assumes is true |
| 3+ | The evidence: `file:line`, numbers, commands run; a *pre-mortem* — it's six months later and this went badly, what happened? — and the same for not doing it |

Each level adds under the last; don't repeat it. Close with one line saying what the next weigh
would add.

### Level 1 shape

```
**The decision**
<one sentence: what changes if yes>

**Why do it**
- <reason — concrete example, what it gets>
- <reason — …>

**Why not**
- <reason — concrete example, what it costs or risks>
- <the rival: do nothing / cheaper version — and why it might be enough>

**It hinges on**
<the one or two questions that decide it: "If X, do it. If not, don't." Say which ones you could
 check and which only the user knows>

**Lean**
<do it / don't / do the cheaper version> — <confidence: low/medium/high> — <what would flip it>
```

## Rules

- **The crux is the point of the exercise.** Most pros and cons don't matter; find the one fact or
  value judgement the decision actually turns on. If you can check it, check it before the lean.
- **A lean, not a verdict.** Always give one; never start the work on it. The decision is the user's.
- **No false balance.** Equal effort doesn't mean equal weight — if one side is clearly stronger,
  the lean says so at high confidence.
- **Scope is the decision they named** — depth goes down into it, not sideways into the project.

## Follow-ups

- **"Weigh again" / "more"** → next level down.
- **"I don't follow that point"** → `duck` it: that point only, in duck's level-1 shape, then back
  here.
- **"Argue harder for/against"** → that side only, next level down, still honest.
- **The user decides** → act on it. No re-weighing.
