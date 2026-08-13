---
name: sitrep
description: >-
  Give a very succinct summary of the current state of the work — what's done, what remains, and
  what needs the user's decision to continue. Use when the user asks "where are we", "what's the
  status", "recap", "summarize the work so far", "what's left", "what do you need from me",
  "¿en qué vamos?", "resumen", or picks the thread back up after a break. Grounded in observed
  state (git, PRs, CI, tests), capped at three short sections, and every blocking choice comes
  with a recommendation.
---

# Sitrep — state of the work, in under 15 lines

Three sections, nothing else. No preamble, no narration of what you checked, no closing offer.

```
**Done**
- <one line, past tense, with the artifact — file:line, commit, PR url>   (max 5)

**Remaining**
- <one line, next-first>                                                 (max 5)

**Needs you**
- <the choice> — recommend: <option>, because <half a line>              (max 3)
```

If nothing is blocked, `**Needs you**` reads exactly: `Nothing blocked.`

## Rules that make it honest

- **Observe, don't recall.** Before writing, check the actual state: `git status`, `git log`, open
  PRs and their CI, the task list, the last test run. A summary from memory drifts from the tree.
- **"Done" means verified.** Written-but-unrun, unpushed, or untested work belongs in
  **Remaining**, with the reason in the same line ("auth refactor — written, tests not run").
- **Name the gaps.** What you skipped, what failed, what you couldn't verify. A gap left out of
  the summary is the failure mode this skill exists to prevent.
- **Decisions, not permission.** **Needs you** is for choices where different answers mean
  materially different work. "Shall I continue?" is not one — decide and proceed. Every entry
  carries a recommendation.
- **Point, don't paste.** `file:line`, commit sha, PR url. No diffs, no logs, no code blocks.
- **One line each.** No nested bullets, no sub-clauses stacked with semicolons. If a bullet needs
  a paragraph, it's a bad bullet — cut it to the fact that changes what happens next.
- **Asked mid-task?** Answer from what you already know plus a cheap state check, then resume.
  The sitrep is a status read, not a pause.
