---
name: tldr
description: >-
  Compress the wall of text just produced into the few lines that change what the user does next —
  the outcome, the load-bearing facts, the buried caveats, the pending decision. Use when the user
  says "tldr", "tl;dr", "too long", "short version", "bottom line", "in short", "condense that",
  "I'm not reading all that", "resúmelo", "en corto", "hazme un tldr", or asks what a long block of
  output actually means. Compresses text that already exists — the last answer, a subagent report, a
  review, a log — rather than checking the state of the work.
---

# TL;DR — the wall of text, minus the wall

Re-read what is already on screen and emit the short version. **No new tool calls, no new work, no
new claims.** Needs fresh state → that is `/sitrep`, which observes the tree; this compresses text.

Target: the assistant's most recent long output, or the last few if they piled up. If the user names
one ("tldr that review", "tldr the subagent's report", "tldr this file"), compress that — reading a
named file or PR is fetching the source, not new work.

```
<one sentence: the bottom line — what happened, or the answer>

- <fact that changes what happens next>                      (3–5 bullets, hard cap 5)

**Caveats** — <what failed, was skipped, went unverified>     (drop if none)
**Needs you** — <the choice> — recommend <option>             (drop if none)
```

Twelve lines hard cap, aim for a tenth of the source. Never re-print the long version.

## The cut

Test per line: **would the user do something different if it were missing?** No → cut.

| Never cut | Always cut |
|---|---|
| Failures, errors, what wasn't verified | Process narration |
| A question asked of the user | The plan, restated |
| Numbers, `file:line`, commands, error strings | Code blocks, diffs, logs — point instead |
| Caveats and assumptions the source stated | Output already on screen |
| A concern or disagreement raised | Rejected approaches, unless the rejection is the decision |
| The trade-off behind a recommendation | Hedges, praise, closing offers |

**Cut narration, never nouns.** Not "found several issues in the auth code" but "3 failing cases in
`verifyToken` — expired, wrong `aud`, `alg: none`". Every name carries the clause that resolves it.

## Honesty

- **Faithful, not flattering.** Failed stays failed; uncertain stays uncertain.
- **A buried caveat is the highest-value line** — "couldn't verify X" from paragraph six gets
  promoted, not dropped.
- **Never summarize away a question.** It survives in **Needs you**, with a recommendation.
- **No new claims.** If compressing surfaces a mistake in the source, flag it as a correction in one
  line; don't silently patch it.
- A recommendation keeps its half-line of why.

## Follow-ups

- "Expand on 2" → that bullet only, no re-emitting the wall.
- `/tldr` twice → only what is new since the last one.
- Source was already short → say so in one line rather than inflating it.
