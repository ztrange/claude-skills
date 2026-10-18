---
name: handoff
description: >-
  Write a self-contained prompt that resumes this work in a fresh context — a new session, another
  machine, or right after /clear — as a markdown file, and hand back its path. Use when the user
  says "write me a handoff", "prompt to continue", "I'm going to clear the context", "continue this
  in a new session", "pick this up tomorrow", "context is getting full", "pásame el prompt para
  continuar", or when a compaction is imminent and unfinished work would be lost. Carries the
  objective, observed state, the next concrete action, the dead ends worth not repeating, and the
  working mode — veri where the project already uses it, `/delegate` for the rest. Two kinds,
  selected by argument: `/handoff reset` is for this same session after a `/clear` and records the
  session's name and id so the resuming agent can check the paste landed in the right session;
  `/handoff delegate` is for a different session or machine and deliberately carries no such check.
  No argument → inferred from what they said.
---

# Handoff — a file that survives /clear

**For the next agent, not the user**: second person, imperative, no pronoun pointing at this
session. (A status report is for the user; this hands an agent enough to work without a catch-up
question.)

**Short.** 25 lines in the file, 40 the hard cap, session check excluded. Cut any line that does not
change the next action; drop empty sections.

## Delivery — a file plus one line

Write the markdown to the scratchpad directory as `handoff-<kind>-<slug>-<YYYYMMDD>.md` — `kind` is
`reset` or `delegation`, so the path itself says which it is, and the path is all the user sees before
pasting it. Then reply with exactly one line, **always inside a fenced code block**:

````
```
Read this handoff prompt and resume the session: /abs/path/to/handoff-reset-<slug>-<date>.md
```
````

Nothing else in the reply — no summary, no pasted copy; prose beside the line makes it a selection
job. Absolute path always; the next session may start elsewhere.

- Must outlive this machine's temp cleanup (another machine, next week) → write it under the user's
  home or the repo, and say which.
- Asked for it inline ("just print it", "paste it here") → print the block in chat instead of the
  file, not as well as.
- Re-generate rather than edit a stale file; a handoff is a snapshot.

## Which kind — from the argument, or inferred

`/handoff <kind>` picks it. Case-insensitive, and these are the whole accepted set:

| Argument | Kind | Identity block |
|---|---|---|
| `reset`, `clear`, `self`, `same` | **Reset** — comes back to *this* process after a `/clear` | **Yes** |
| `delegate`, `delegation`, `portable`, `send`, `other`, `new` | **Delegation** — a different session, agent or machine | **No** |

**An unrecognised argument is not a kind.** Say what you got and the two valid ones; never guess
which was meant, and never treat it as a slug for the filename.

No argument → infer, then build it without asking:

| They said | Kind |
|---|---|
| "I'm going to clear the context", "context is getting full", a compaction is imminent | **Reset** |
| "pick this up tomorrow", "continue this in a new session", "another machine", "send this to another session" | **Delegation** |

Neither fits → ask, in one line. Guessing wrong either blocks the session meant to pick it up or
drops the check that stops a paste landing in the wrong tree.

A **delegation** handoff is not the `/delegate` skill: that one runs subagents inside this session,
this one hands the whole task to a session you are not driving. The `/delegate` line inside
**Working mode** is advice to the recipient, and appears in both kinds.

**Reset handoffs open with a session check, before `## Objective`.** `/clear` keeps the process, so
name and id survive it — the only thing a resuming agent can check:

```
get_session with session_id: "self"   → .title (what /name sets) and .sessionId
```

Fill this in at the top of the file:

```markdown
## Session check — do this first
This handoff belongs to the session named "<title>" (`<sessionId>`), worktree <abs path>.
Verify with `get_session` on `"self"` and compare the name; if the name was changed since, compare
`sessionId`, which does not change. No session tooling available → compare the worktree path from
`git rev-parse --show-toplevel`.
Doesn't match → stop. Say which session this handoff is for and do nothing else.
```

**Delegation handoffs carry no such block**, deliberately: an identity gate would refuse the very
session it was written for. `## State`'s repo, branch and worktree path pin them to a tree without
blocking.

## The file

```markdown
## Objective
<what the user wants, 1–2 sentences — the goal, not the last step taken>

## State
- repo: <abs path>   branch: <name>   worktree: <abs path, if any>
- HEAD: <sha> <subject>          working tree: <clean | files>
- PR: <url + state>              CI: <passing | failing | none>
- touched: <file:line — what changed and why, one line each>

## Done
- <verified, past tense>          (max 5)

## Next
1. <first concrete action, specific enough to start on>
2. <then>                         (max 5)

## Working mode
- Development goes through veri (`/tdd <n>`). Everything else goes through `/delegate`, as much as
  possible, to keep this context small.
  ← keep the veri line only if the project already uses veri; otherwise just the `/delegate` one

## Constraints
- <rule the user set, in their words>
- <house rule that applies: branch→PR, never push to main, work only in the repo above, …>

## Already tried — don't redo
- <approach> → <what happened, why dropped>

## Gotchas
- <the surprise that cost time: a flag, a path, a tool that no-ops silently>

## Verify with
<exact command, absolute paths, flags>

## Open decisions
- <choice> — recommend <option>. Ask the user before proceeding.
```

**Working mode** is never empty: it always carries the `/delegate` line.

## The veri line is conditional

Say it only when the project **already uses veri**, observed in the repo, not from memory. Any one
is enough:

| Signal | Check |
|---|---|
| Run-state directory | `ls -d <repo>/.tdd` |
| The ignore rule veri installs | `grep -nxF '.tdd/*' <repo>/.gitignore` |
| A veri branch | `git -C <repo> branch -a --list '*tdd/*'` |
| The opt-in label | `gh label list -R <owner/repo> --search ready-for-agent` |
| Named in the repo's own instructions | `grep -n -w -i 'veri\|tdd' <repo>/CLAUDE.md` |

None → the `/delegate` line alone. A handoff is not where veri adoption gets decided.

## What makes it worth reading

- **The dead ends are the point** — what was tried, abandoned and why dies with `/clear`. Rank it
  above a summary of what worked.
- **Observed, not remembered** — real sha, branch, PR state and `git status`, read as you write.
- **Point, don't paste** — `file:line`, not contents.
- **Self-contained** — absolute paths, no "the file we discussed", the user's constraints in their
  own words.
- **Start-able** — the first **Next** item is a command, a file to edit, or a question. "Continue
  the refactor" is not.
- **No secrets** — name the env var instead.
