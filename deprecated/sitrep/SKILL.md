---
name: sitrep
description: >-
  Succinct state of the work — what's done, what remains, what needs the user's decision. Use when
  the user asks "where are we", "what's the status", "recap", "summarize the work so far", "what's
  left", "what do you need from me", "¿en qué vamos?", "resumen", or picks the thread back up after
  a break. Grounded in observed state (git, PRs, CI, tests), three capped sections, every blocking
  choice carries a recommendation.
---

# Sitrep — state of the work, under 15 lines

```
**Done**
- <past tense, carrying the artifact — file:line, sha, PR url>   (max 5)

**Remaining**
- <next-first>                                                   (max 5)

**Needs you**
- <the choice> — recommend: <option>, because <half a line>      (max 3)
```

Drop an empty section. Nothing blocked → **Needs you** reads exactly `Nothing blocked.`

- **Observe, don't recall.** `git status`, `git log`, open PRs and their CI, last test run — before
  writing.
- **Done means verified.** Written-but-unrun, unpushed or untested goes to **Remaining** with the
  reason inline: "auth refactor — written, tests not run".
- **Name the gaps**: what you skipped, what failed, what you could not verify.
- **Needs you is decisions, not permission.** "Shall I continue?" is not one — decide and proceed.
- Point, don't paste: `file:line`, sha, url. One line per bullet, no nesting.
- Asked mid-task → answer from what you have plus one cheap state check, then resume.
