---
name: duck
description: >-
  Re-explain whatever is on the table from zero, to the user, as if they had just walked in — a
  decision they're being asked to make, one of the options being offered, or something just
  reported. The mechanism before the failure, every name resolved, what was already ruled out, and
  the ask stated so it can actually be answered. Use when the user says "duck", "duck it", "duck
  this", "talk to the duck", "explain it to the duck", "I don't follow", "I don't understand what
  you're asking me", "explain that from scratch", "assume I know nothing about this", "what do you
  mean by that option", "explain that second one", "what did you just find", "what does that error
  actually mean", "start over, I just walked in", "explícamelo desde cero", "no entiendo qué me
  estás pidiendo", or when an answer comes back that resolves a different question than the one
  asked. Expands rather than compresses — the opposite of /tldr.
---

# Duck — explain it to whoever just walked in

In the story you explain the problem to a rubber duck and solve it yourself. Here the duck is the
user, and the duck answers back — but only if the explanation is complete enough to be advised on.
This skill is that explanation.

The failure it fixes: forty tool calls deep, everything has a name — a file, a branch, a helper, a
workaround someone put in eight months ago. The question that comes out ("keep the fallback in
`resolveBinding` or hoist it to the caller?") is answerable only from inside that context. The user
has been doing something else. So they answer the question they think was asked, or they tell you to
just decide — and a decision that needed them got made without them.

| | Written for | Direction |
|---|---|---|
| `/tldr` | the user, who already read it | shorter |
| `/sitrep` | the user, who is already in it | status, observed |
| `/handoff` | the next agent | portable |
| **`/duck`** | **the user, cold** | **longer, complete** |

## First, what is being ducked

Three different things get ducked, and they do not want the same sections. Read what the user
pointed at, not the habit:

| Ducked | What they're actually asking | Sections |
|---|---|---|
| **A decision** — "what are you asking me?" | the whole choice, from zero | full shape |
| **An option** — "what does that one mean?" | one branch expanded | option shape |
| **A finding** — "what did you just tell me?" | a report they can't parse | finding shape |

Two parts never vary: **What this is about**, and the rules further down. Everything else is
chosen. A section with nothing real behind it gets cut, not filled — a padded **What I've tried**
on something you found on the first read, or a manufactured question on something that was never a
decision, is how this goes wrong.

Whichever shape: one screen. No preamble, no "let me back up a bit", no apology for the length.

### Ducking a decision

```
**What this is about**
<2–4 sentences: what the thing is, what it's for, why we're touching it at all>

**What I've tried**
- <attempt — what happened>                        (max 4; include what was ruled out and why)

**Where it's stuck**
<mechanism first — what it's supposed to do — then what it does instead>

**What I need from you**
<the choice, as options, each with what it costs>
Recommend: <option>, because <half a line>
```

### Ducking an option

They already have the decision; they want one branch of it opened up. Don't re-litigate the
decision, and don't re-explain the options they didn't ask about beyond how they differ.

```
**What this is about**
<2–3 sentences: the decision this option belongs to, and what turns on it>

**What this option actually does**
<mechanism: the change it makes, where, in what order — concrete, `file:line`>

**What it costs**
<what it gives up, what it commits us to later, what it makes harder>

**Against the others**
- <other option — the one line where it differs>
```

Close with the decision restated in a line — it is still live and still theirs. **What I've tried**
earns a place here only when an attempt is *why* this option exists ("the direct call was the
obvious one; it deadlocks, so this is the fallback").

### Ducking a finding

Something was reported — a bug, a risk, a review comment, a surprising log line — and the report
was unreadable. There may be no decision attached at all.

```
**What this is about**
<2–3 sentences: the thing, what it's for, why it was being looked at>

**What it's supposed to do**
<the mechanism, one or two sentences>

**What it does instead**
<the failure — the one excerpt goes here, if the exact wording is the point>

**How I know**
<what was observed — command, `file:line`, log — and what is inference>

**What it means**
<who hits it, when, how bad, and whether anything is broken right now>
```

Then one of two endings, never both and never neither: **What I need from you** if a real choice
falls out of it, or a single line of what happens next if it doesn't. Do not invent a question to
fill the slot.

## Rules that make it land

- **Assume zero prior context.** No "as I mentioned", no "the file we were looking at", no "the
  same issue as before". The test: could a colleague who sat down thirty seconds ago read it top
  to bottom without scrolling up? If a sentence needs the conversation to parse, rewrite it.

- **Translate the sentence, not the vocabulary.** A term of art keeps its name and gets a short
  gloss anchored to *this* task — "*idempotent* — running the import twice leaves the same rows".
  Don't swap it for an easier word: the user needs that term to answer you, and to ask the next
  question. Simplifying the words while keeping the density fixes nothing.

- **Every name resolves.** `#412`, `verifyToken`, `--ff-only`, the branch, the error string — each
  arrives with the clause that says what it is. Unresolved names are where the misunderstanding
  was living in the first place.

- **Mechanism before failure.** One sentence on what the code is supposed to do, then what it does
  instead. A bug described before its mechanism is noise.

- **Observe, don't recall.** Re-read the file, re-run the command, re-check the PR before
  describing them. Explaining from memory reproduces the same context that already lost the user,
  with the wrong parts intact — and risks briefing them on a tree that has moved.

- **Mark the guesses.** Separate what you verified from what you're inferring. Advice is only as
  good as knowing which is which, and this is exactly where a confident sentence does damage.

- **Say what you ruled out, and why.** One line each. Skip it and the first suggestion back is the
  dead end you already walked.

- **A live ask has to be answerable.** Options, costs, a recommendation. "What do you think?" is
  not a question. If the answer wouldn't change what you do next, it isn't a decision — say what
  happens next instead of asking. That exemption is for something that was never a decision, not
  for one you answered yourself on the way here: a decision that was live before the duck is still
  live after it.

- **At most one excerpt.** A trimmed error, a few lines of the file — and only when the exact
  wording is the thing being decided. Otherwise point: `file:line`.

- **Scope is what they pointed at.** The decision, the one option, the one finding — not the
  project. If it doesn't fit a screen you've started giving a tour of the codebase.

## When explaining it solves it

Sometimes the answer falls out while you're writing — that is the story working. It changes what
goes under **What I need from you**. It does not delete that section, and it does not start the
work.

- **Still stop, and still ask.** Even when the answer looks obvious. Finding it while explaining
  doesn't convert the decision into yours — the whole reason you were writing is that this one
  wasn't. Acting on it puts the user back where `/duck` was invoked to get them out of: told
  afterwards.
- **Say where it came from.** Don't present a conclusion reached three paragraphs ago as if it had
  been the plan all along.
- **It's a proposal, not a finding.** It came out of re-reading and reasoning, not out of running
  anything. Say which parts you actually checked and which you didn't, and don't go verify it
  first — that's doing the work before the decision.
- **Keep the alternatives on the page.** The options you were about to lay out are still the
  options. An answer you like doesn't get to be the only one offered.

> Writing this out surfaced `<what>`, which points at `<the answer>`. That's reasoning — I haven't
> run anything against it. Options are still `<a>` and `<b>`; recommend `<the answer>`, because
> `<half a line>`. Your call.

## Follow-ups

- **"Still lost" / "duck it again"** — start one level further out, don't repeat the same words
  louder. Find the assumption the first version leaned on without stating, and begin there.
- **"That's not what I asked"** — they were pointing at one option or one finding and got the whole
  decision. Re-duck at that scope, in that shape.
- **Answered with a decision** — act on it. No re-briefing, no confirming it back.
- **"Duck the caching part"** — scope to that piece, same rules, shorter.
