---
name: handoff
description: >-
  Write a self-contained prompt that resumes this work in a fresh context — a new session, another
  machine, or right after /clear — save it as a markdown file and hand back its path. Use when the
  user says "write me a handoff", "prompt to continue", "I'm going to clear the context", "continue
  this in a new session", "pick this up tomorrow", "context is getting full", "pásame el prompt para
  continuar", or when a compaction is imminent and unfinished work would be lost. Carries the
  objective, observed state, the next concrete action, the dead ends worth not repeating, and the
  working mode — veri for development where the project already uses it, `/delegate` for the rest. A
  handoff for this same session after a `/clear` also records the session's name and id so the
  resuming agent can check the paste landed in the right session; one written for a different
  session deliberately carries no such check.
---

# Handoff — a file that survives /clear

Written **for the next agent, not the user**: second person, imperative, no reference to "our
conversation". A line that only parses for someone who read this session is broken. (`/sitrep` tells
the user where things stand; this hands an agent enough to work without a catch-up question.)

**Short.** 25 lines in the file is the target, 40 the hard cap, not counting the session check. Cut every line that does not change
the next action — the handoff exists to save context, not to relocate it. Drop an empty section
rather than padding it.

## Delivery — a file plus one line

Write the markdown to the scratchpad directory as `handoff-<slug>-<YYYYMMDD>.md`, then reply with
exactly one line, **always inside a fenced code block** so it is one click to copy:

````
```
Read this handoff prompt and resume the session: /abs/path/to/handoff-<slug>-<date>.md
```
````

The fence is not decoration — that line exists to be copied into the next session, and prose around
it or beside it makes it a selection job. Nothing else in the reply: no preamble, no summary of the
file, no pasted copy of it. Absolute path always; the next session may start in a different
directory.

- Needs to outlive this machine's temp cleanup (another machine, next week) → write it under the
  user's home or the repo instead, and say which.
- Asked for it inline ("just print it", "paste it here") → print the block in chat instead of, not
  as well as, the file.
- Re-generate rather than edit a stale file. A handoff is a snapshot.

## Which handoff is this — and only one kind gets an identity check

| They said | Kind | Identity block |
|---|---|---|
| "I'm going to clear the context", "context is getting full", a compaction is imminent | **Same session, cleared** — it comes back to *this* process | **Yes** |
| "pick this up tomorrow", "continue this in a new session", "another machine", "send this to another session" | **Portable** — meant for a different session | **No** |

Neither fits → ask, in one line. The two files differ, and a wrong guess either blocks the session
that was supposed to pick it up or drops the check that stops a paste landing in the wrong tree.

**Same-session handoffs open with a session check, before `## Objective`.** `/clear` keeps the same
process, so the session's own name and id survive it — which makes them the one thing a resuming
agent can check to know the paste landed where it was meant to. Read them as you write:

```
get_session with session_id: "self"   → .title (what /name sets) and .sessionId
```

Then put this at the top of the file, filled in:

```markdown
## Session check — do this first
This handoff belongs to the session named "<title>" (`<sessionId>`), worktree <abs path>.
Verify with `get_session` on `"self"` and compare the name; if the name was changed since, compare
`sessionId`, which does not change. No session tooling available → compare the worktree path from
`git rev-parse --show-toplevel`.
Doesn't match → stop. Say which session this handoff is for and do nothing else.
```

**Portable handoffs carry no such block**, and the omission is deliberate: an identity gate there
would refuse exactly the session it was written for. They are still pinned to a tree by `## State`'s
repo, branch and worktree path, which a reader can sanity-check without being blocked by it.

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

Say it only when the project **already uses veri**, decided from something observed in the repo, not
from memory. Any one is enough:

| Signal | Check |
|---|---|
| Run-state directory | `ls -d <repo>/.tdd` |
| The ignore rule veri installs | `grep -nxF '.tdd/*' <repo>/.gitignore` |
| A veri branch | `git -C <repo> branch -a --list '*tdd/*'` |
| The opt-in label | `gh label list -R <owner/repo> --search ready-for-agent` |
| Named in the repo's own instructions | `grep -n -w -i 'veri\|tdd' <repo>/CLAUDE.md` |

None → the `/delegate` line alone. A handoff is not where veri adoption gets decided.

## What makes it worth reading

- **The dead ends are the point.** What was tried, abandoned, and why, is the expensive knowledge; it
  does not survive `/clear`. Rank it above a tidy summary of what worked.
- **Observed, not remembered.** Read the real sha, branch, PR state and `git status` as you write.
- **Point, don't paste.** `file:line`, not file contents.
- **Self-contained.** No "the file we discussed", no pronouns pointing at this session. Absolute
  paths. The user's constraints in their own words, not a citation of where they said them.
- **Start-able.** The first **Next** item is a command to run, a file to edit, or a question to ask.
  "Continue the refactor" is not.
- **No secrets** — name the env var instead.
