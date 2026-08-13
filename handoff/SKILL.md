---
name: handoff
description: >-
  Write a self-contained prompt that resumes this work in a fresh context — a new session, another
  machine, or right after /clear. Use when the user says "write me a handoff", "prompt to
  continue", "I'm going to clear the context", "continue this in a new session", "pick this up
  tomorrow", "context is getting full", "pásame el prompt para continuar", or when a compaction is
  imminent and unfinished work would be lost. Emits a paste-ready block carrying the objective,
  observed state, the next concrete action, and the dead ends worth not repeating.
---

# Handoff — a prompt that survives /clear

The output is written **for the next agent, not for the user**: second person, imperative, no
reference to "our conversation". If a line only makes sense to someone who read this session, it's
broken.

Not the same as `/sitrep`. Sitrep tells the user where things stand; a handoff hands an agent
enough to keep working without asking a single catch-up question.

## The block

One fenced block, paste-ready, ~40 lines max:

````
```
## Objective
<what the user wants, one or two sentences — the goal, not the last step taken>

## State
- repo: <abs path>   branch: <name>   worktree: <abs path, if any>
- HEAD: <sha> <subject>          working tree: <clean | files>
- PR: <url + state>              CI: <passing | failing | none>
- touched: <file:line — one line each, what changed and why>

## Done
- <verified, past tense>          (max 5)

## Next
1. <the first concrete action, specific enough to start on>
2. <then>                         (max 5)

## Constraints
- <rule the user set, in their words>
- <house rule that applies: branch→PR, never push to main, …>

## Already tried — don't redo
- <approach> → <what happened, why it was dropped>

## Gotchas
- <the surprise that cost time: a flag, a path, a tool that no-ops silently>

## Verify with
<the exact command, absolute paths, flags included>

## Open decisions
- <choice> — recommend <option>. Ask the user before proceeding.
```
````

Drop any section that would be empty. Never pad one.

## What makes it worth pasting

- **The dead ends are the point.** What was tried and abandoned, and why, is the expensive
  knowledge — it doesn't survive a `/clear` and the next agent will spend the same hour
  rediscovering it. Rank this above a tidy summary of what worked.
- **Observed, not remembered.** Read the real sha, branch, PR state and `git status` as you write.
  A handoff that describes a tree that no longer exists sends the next agent down a wrong path
  with full confidence.
- **Point, don't paste.** `file:line`, not file contents. The next agent can open files; it can't
  un-read a wall of code you inlined.
- **Self-contained.** No "the file we discussed", no "as mentioned above", no pronouns pointing at
  this session. Absolute paths. Spell out the user's constraints in their own words rather than
  citing where they said them.
- **Start-able.** The first item under **Next** must be something an agent can act on immediately
  — a command to run, a file to edit, a question to ask. "Continue the refactor" is not that.
- **No secrets.** No tokens, keys, or credentials in the block. Name the env var instead.
- **Short.** Everything that doesn't change the next action is cut. The handoff exists to save
  context, not to relocate it.

## Delivery

Print the block in chat by default — that's what gets pasted after `/clear`.

Write it to a file as well when the session may end before it's used (new machine, tomorrow, a
cloud run): put it in the scratchpad directory, or in the repo only if the user asks. Say where it
landed. Re-generate rather than edit a stale one — a handoff is a snapshot, and a half-updated
snapshot is the failure mode.
