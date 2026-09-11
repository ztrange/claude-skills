---
name: handoff
description: >-
  Write a self-contained prompt that resumes this work in a fresh context — a new session, another
  machine, or right after /clear. Use when the user says "write me a handoff", "prompt to
  continue", "I'm going to clear the context", "continue this in a new session", "pick this up
  tomorrow", "context is getting full", "pásame el prompt para continuar", or when a compaction is
  imminent and unfinished work would be lost. Emits a paste-ready block carrying the objective,
  observed state, the next concrete action, the dead ends worth not repeating, and the working
  mode — veri for development where the project already uses it, `/delegate` for the rest — so
  the next session keeps its context small from its first turn onwards.
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

## Working mode
- Development goes through veri (`/solve-issue <n>`). Everything else goes through
  `/delegate`, as much as possible, to keep this context small.
  ← keep the veri line only if the project already uses veri; otherwise just the `/delegate` one

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

Drop any section that would be empty. Never pad one. **Working mode** is never empty: it always
carries at least the `/delegate` line.

## Working mode — always present, veri only when observed

The next agent starts with a full budget and no idea how it was meant to spend it. The handoff says
so up front: **development goes through veri, everything else through `/delegate`, as much as
possible, to keep the context small.** Both are skills the next session already has; the handoff
just tells it to reach for them.

The veri line is conditional. Say it only when the project **already uses veri** — and decide
that from something observed in the repo, not from memory of the session. Any one of these is
enough:

| Signal | Check |
|---|---|
| A run-state directory | `ls -d <repo>/.tdd` |
| The ignore rule veri installs | `grep -nxF '.tdd/*' <repo>/.gitignore` |
| A veri branch, local or remote | `git -C <repo> branch -a --list '*tdd/*'` |
| The opt-in label on the issue tracker | `gh label list -R <owner/repo> --search ready-for-agent` |
| The repo's own instructions name it | `grep -n -w -i 'veri\|solve-issue' <repo>/CLAUDE.md` |

None of them → the section is the `/delegate` line alone. Don't recommend veri to a project that
hasn't adopted it; a handoff is not where that decision gets made.

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
