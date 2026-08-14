---
name: tldr
description: >-
  Compress the wall of text just produced into the few lines that actually change what the user
  does next — the outcome, the load-bearing facts, the buried caveats, the pending decision. Use
  when the user says "tldr", "tl;dr", "too long", "short version", "bottom line", "in short",
  "condense that", "I'm not reading all that", "resúmelo", "en corto", "hazme un tldr", or asks
  what a long block of output actually means. Summarizes text that already exists — the last
  answer, a subagent report, a review, a log — rather than checking the state of the work.
---

# TL;DR — the wall of text, minus the wall

Re-read what's already on screen and emit the short version. **No new tool calls, no new work, no
new claims.** If answering needs fresh state, this is the wrong skill — that's `/sitrep`.

Not the same as `/sitrep`: sitrep observes the tree, git, PRs and CI to say where the *work*
stands. A tldr compresses *text that has already been written*, and adds nothing that wasn't in it.

## What to compress

By default: the assistant's most recent long output — the last answer, or the last few if the user
has been letting them pile up.

If the user names a target ("tldr that review", "tldr the subagent's report", "tldr this file"),
compress that instead. Reading a named file or PR is fine; that's fetching the source, not doing
new work.

## The shape

```
<one sentence: the bottom line — what happened, or the answer>

- <fact that changes what happens next>                      (3–5 bullets, hard cap 5)

**Caveats** — <what failed, was skipped, or went unverified>  (drop the line if none)
**Needs you** — <the choice> — recommend <option>             (drop the line if none)
```

No heading, no preamble, no "here's the summary". Twelve lines is the hard cap; aim for a tenth of
the source. Never re-print the long version — the tldr replaces it.

## The cut

The test for every line: **would the user do something different if this line were missing?** If
no, cut it.

| Never cut | Always cut |
|---|---|
| Failures, errors, what wasn't verified | Process narration — "first I looked at", "then I ran" |
| A question that was asked of the user | The plan, restated |
| Numbers, `file:line`, commands, error strings | Code blocks, diffs, logs — point at them instead |
| Caveats and assumptions the long version stated | Output already on the user's screen |
| A concern or disagreement that was raised | Approaches considered and rejected, unless the rejection is itself the decision |
| The trade-off behind a recommendation | Hedges, praise, closing offers |

**Cut narration, never nouns.** A tldr that says "found several issues in the auth code" is worse
than the wall of text it replaced. It's "3 failing cases in `verifyToken` — expired, wrong `aud`,
`alg: none`". Anything named has to carry the clause that resolves it, because the user's context
is not the agent's.

## Honesty rules

- **Faithful, not flattering.** If the long version failed, the tldr says failed. If it was
  uncertain, the tldr is uncertain. Compressing is not an excuse to round up to success.
- **A buried caveat is the highest-value line.** "Couldn't verify X" in paragraph six of the wall
  is exactly what the user missed. It gets promoted, not dropped.
- **Never summarize away a question.** If the long version asked something, it survives in
  **Needs you**, with a recommendation.
- **No new claims.** Nothing appears in the tldr that isn't in the source. If compressing surfaces
  a mistake in the long version, say so in one line, marked as a correction — don't silently
  patch it.
- **Decisions keep their context.** A recommendation without the trade-off is unusable. One
  half-line of why is not padding.

## Follow-ups

- "Expand on 2" → expand that bullet only. Don't re-emit the wall.
- `/tldr` twice in a row → summarize only what's new since the previous one.
- Nothing worth compressing (the last output was already short) → say so in one line rather than
  inflating three bullets out of two sentences.
