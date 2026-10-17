---
name: delegate
description: >-
  Work through subagents to keep the main context clean: the main thread orchestrates and holds
  conclusions, subagents absorb the raw material (file dumps, search sweeps, build logs, long tool
  output) and report back compressed. Use when the user asks to "delegate", "use subagents", "run
  this in agents", "farm this out", "keep the context clean/small", "don't fill my context", or when
  they hand over a multi-part task to be done in parallel. Covers delegate-vs-inline, the
  self-contained prompt with an explicit return contract, parallel fan-out and worktree isolation
  for concurrent writes, following up via SendMessage instead of respawning, and how the
  orchestrator verifies and relays without re-reading everything.
---

# Delegate — solve tasks in subagents, keep the main context clean

**The main thread decides, subagents read.** Raw material — whole files, search sweeps, build and
test logs, dependency trees, API dumps — burns context that never comes back. Push it into a
subagent and keep what changes a decision: the conclusion, the `file:line`, the failing assertion.

Invoking this skill **is** the user asking for delegation; any standing instruction to avoid the
Agent tool unless requested is satisfied for the rest of the task. Don't ask again.

## What goes out

| Delegate | Do inline |
|---|---|
| A question answered by reading across several files | A fact in a file you already know |
| Broad searches ("where is X handled", "find all callers") | One `grep` whose shape you can predict |
| Long output — logs, CI runs, generated data, big JSON | A command with 5 lines of output |
| Independent parts of a multi-part task (fan out) | Steps that depend on each other |
| Anything ending "…and tell me if it's fine" | Editing a file you've already read |
| Exploratory work likely to be a dead end | The final edit the user will review |

Both failure modes are real: reading 12 files into the main thread to answer one question, and
spawning an agent to run `git status`. Under ~3 cheap tool calls, do it yourself.

Never delegate the *decision*. A subagent gathers and proposes; the main thread chooses and speaks.

## The contract

A subagent starts blank — it cannot see this conversation or what you already tried. Five parts:
**goal** (one sentence), **context** (paths, stated constraints, what's ruled out and why — pasted,
not "the file we discussed"), **boundaries** (what it may change, whether it may commit or push —
default no, and **which repo**), **return contract** (exact shape, size cap), **exclusions**.

```
Goal: <one sentence>

Context:
- repo: <abs path>
- <constraint / prior finding / rejected approach, one line each>

Do: <steps or scope>
Do not: <edit, commit, push, touch X>
Do not touch any repo other than the one above — if the fix lives elsewhere, say so and stop.

Return, under 20 lines:
- verdict: <one line>
- evidence: file:line per claim
- <the 2-3 fields you'll actually use>
Do not paste file contents, full diffs, or logs. Cite file:line and quote at most the
failing line.
```

Name the repo explicitly: a blank subagent does not know the scope rule you're under, and "fix this
properly" reads as permission to edit whatever repo the cause turns out to live in. Without a return
contract agents send back everything they read, which moves the bloat rather than removing it.

## Fan out

Independent work goes in **one message with multiple Agent calls**. Dependent work waits, and the
second prompt carries the first one's answer.

- **Background by default**; you're notified on finish. `run_in_background: false` only when your
  very next action needs the result and nothing else can usefully happen.
- **Never predict a pending agent's result.** Asked before the notification lands → say it's running.
- **Parallel writes need isolation** — `isolation: "worktree"` each, or better, keep writes in the
  main thread and let agents only investigate.
- **Cap at 3–6** for a normal task; past that, synthesis costs more than the parallelism saves.

Split by **subsystem or question**, never by file — one agent per file means N reports that all need
cross-referencing back in the main thread.

## Type, then model

Type decides tools: `Explore` for read-only search fan-out, `Plan` for implementation strategy,
`general-purpose` / `claude` for anything that writes.

Then `model: "haiku" | "sonnet" | "opus" | "fable"`, which overrides the agent definition's default:

| | Work | Model |
|---|---|---|
| **Gathering** | searching, reading many files for one answer, collecting call sites, summarising a log | Cheap — the agent compresses, you judge |
| **Judging** | reviewing for correctness, choosing between approaches, adversarially verifying, anything you'd act on without re-deriving | Strong — downgrading moves the error into a report you will trust |

Test: **if this report is wrong, will you notice?** A missed call site announces itself when the
change fails. A plausible "nothing else references this, safe to delete" does not.

Fan-out compounds the saving: five cheap gathering agents under one strong orchestrator. Omitting
`model` takes the agent definition's own, and `fork` ignores the parameter — a fork inherits the
parent's model.

## Follow up, don't respawn

A second `Agent` call pays the whole ramp-up again. `SendMessage` to the agent's ID or name continues
it with context intact — "now also check X", "the fix broke test Y", "line number for that third
claim". `ListAgents` shows who's reachable.

## Orchestrator hygiene

- **The report is not shown to the user.** Relay what matters in your own words; findings you never
  surfaced are work the user never received.
- **Verify cheaply and narrowly** — read the one line it cited, run the one test it claims passes.
  Re-reading everything defeats the delegation; trusting blindly is the other failure. Anything
  load-bearing (a number, "the tests pass", "nothing else calls this") gets one targeted check.
- **Carry forward the conclusion and the pointers, drop the transcript.**
- **Report faithfully** — an agent that failed, returned nothing, or was skipped gets said.

## Anti-patterns

| Don't | Do |
|---|---|
| "Look into the auth module and report back" | A specific question with a return contract |
| Delegate, then read the same files yourself | Trust the report; spot-check one cited line |
| Paste the agent's full report to the user | Relay the conclusion and what it means |
| One agent per file across 20 files | One agent per question, across the files it needs |
| Respawn for a follow-up | `SendMessage` to the running agent |
| Let a subagent commit, push, or open a PR | Keep outward-facing actions in the main thread |
| Let a subagent fix it in another repo | Name the one repo in boundaries; a cross-repo cause comes back as a finding |
