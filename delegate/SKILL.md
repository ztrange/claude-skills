---
name: delegate
description: >-
  Work through subagents to keep the main context clean: the main thread orchestrates and holds
  conclusions, subagents absorb the raw material (file dumps, search sweeps, build logs, long tool
  output) and report back compressed. Use when the user asks to "delegate", "use subagents", "run
  this in agents", "farm this out", "keep the context clean/small", "don't fill my context", or when
  they hand over a multi-part task to be done in parallel. Covers delegate-vs-inline, the
  self-contained prompt and its return contract, fan-out, worktree isolation for concurrent writes,
  SendMessage follow-ups, and verifying and relaying without re-reading everything.
---

# Delegate — solve tasks in subagents, keep the main context clean

**The main thread decides, subagents read.** Raw material burns context that never comes back; keep
only what changes a decision — the conclusion, the `file:line`, the failing assertion.

Invoking this skill **is** the request: any standing instruction to avoid the Agent tool unless
asked is satisfied for the rest of the task. Don't ask again.

## What goes out

| Delegate | Do inline |
|---|---|
| A question answered by reading across several files | A fact in a file you already know |
| Broad searches ("where is X handled", "find all callers") | One `grep` whose shape you can predict |
| Long output — logs, CI runs, generated data, big JSON | A command with 5 lines of output |
| Independent parts of a multi-part task (fan out) | Steps that depend on each other |
| Anything ending "…and tell me if it's fine" | Editing a file you've already read |
| Exploratory work likely to be a dead end | The final edit the user will review |

Under ~3 cheap tool calls, do it yourself. Never delegate the *decision* — a subagent gathers and
proposes, the main thread chooses and speaks.

## The contract

A subagent starts blank: no conversation, no record of what you tried. Five parts — **goal** (one
sentence), **context** (paths, constraints, what's ruled out and why, pasted, not "the file we
discussed"), **boundaries** (what it may change, whether it may commit or push — default no — and
**which repo**), **return contract** (exact shape, size cap), **exclusions**.

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

Name the repo: a blank subagent doesn't know your scope rule, and "fix this properly" reads as
permission to edit whatever repo the cause lives in. Without a return contract, agents return
everything they read.

## Fan out

Independent work → **one message, multiple Agent calls**. Dependent work waits, its prompt carrying
the first answer.

- **Background by default**; you're notified on finish. `run_in_background: false` only when your
  very next action needs the result and nothing else can usefully happen.
- **Never predict a pending agent's result.** Asked before the notification lands → say it's running.
- **Parallel writes need isolation** — `isolation: "worktree"` each, or better, keep writes in the
  main thread and let agents only investigate.
- **Cap at 3–6**; past that synthesis costs more than the parallelism saves.
- **Split by subsystem or question, never by file** — N per-file reports need cross-referencing back
  here.

## Type, then model

Type decides tools: `Explore` for read-only fan-out, `Plan` for implementation strategy,
`general-purpose` / `claude` for anything that writes.

Then `model: "haiku" | "sonnet" | "opus" | "fable"`, overriding the agent definition's default:

| | Work | Model |
|---|---|---|
| **Gathering** | searching, reading many files for one answer, collecting call sites, summarising a log | Cheap — the agent compresses, you judge |
| **Judging** | reviewing for correctness, choosing between approaches, adversarial verification, anything you'd act on without re-deriving | Strong — downgrading moves the error into a report you will trust |

Test: **if this report is wrong, will you notice?** A missed call site announces itself when the
change fails; a plausible "nothing else references this" does not.

Omit `model` and the agent definition's own applies; `fork` ignores it and inherits the parent's.

## Follow up, don't respawn

A second `Agent` call pays the ramp-up again. `SendMessage` to the agent's ID or name continues it
with context intact ("now also check X"). `ListAgents` shows who's reachable.

## Orchestrator hygiene

- **The report is not shown to the user.** Relay what matters in your own words.
- **Verify narrowly** — anything load-bearing (a number, "the tests pass", "nothing else calls
  this") gets one targeted check: the line it cited, the test it claims passes.
- **Carry the conclusion and the pointers forward, drop the transcript.**
- **Report faithfully** — an agent that failed, returned nothing, or was skipped gets said.

## Never

- **A subagent does not commit, push, or open a PR.** Outward-facing actions stay in the main thread.
- **A subagent does not decide to fix it in another repo.** Name the one repo in boundaries; a
  cross-repo cause comes back as a finding.
