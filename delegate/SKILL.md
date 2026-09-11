---
name: delegate
description: >-
  Work through subagents to keep the main context clean: the main thread orchestrates and
  holds conclusions, subagents absorb the raw material (file dumps, search sweeps, build logs,
  long tool output) and report back compressed. Use when the user asks to "delegate", "use
  subagents", "run this in agents", "farm this out", "keep the context clean/small", "don't fill
  my context", or when they hand over a multi-part task and ask for it to be done in parallel.
  Covers when to delegate vs. do it inline, how to write a self-contained subagent prompt with an
  explicit return contract, parallel fan-out and worktree isolation for concurrent writes,
  following up via SendMessage instead of respawning, and how the orchestrator verifies and
  relays results without re-reading everything.
---

# Delegate — solve tasks in subagents, keep the main context clean

**The rule: the main thread decides, subagents read.** Raw material — whole files, search sweeps,
build and test logs, dependency trees, API dumps — burns context that never gets it back. Push that
into a subagent and keep only what changes a decision: the conclusion, the file:line pointers, the
one failing assertion.

Invoking this skill **is** the user asking for delegation. Any standing instruction to avoid the
Agent tool unless requested is satisfied for the rest of this task — don't ask again.

## What goes to a subagent

| Delegate | Do inline |
|---|---|
| Any question answered by reading across several files | A fact in a file you already know |
| Broad searches ("where is X handled", "find all callers") | One `grep` you can predict the shape of |
| Reading long output — logs, CI runs, generated data, big JSON | A command with 5 lines of output |
| Independent parts of a multi-part task (fan out) | Steps that depend on each other's results |
| Anything that ends in "…and tell me if it's fine" | Editing a file you've already read |
| Exploratory work likely to be a dead end | The final edit that the user will review |

Two failure modes, and both are real:

- **Under-delegating** — reading 12 files into the main thread to answer one question.
- **Over-delegating** — spawning an agent to run `git status`. Setup and report cost more than the
  work. If the whole job is under ~3 cheap tool calls, just do it.

Never delegate the *decision*. A subagent gathers and proposes; the main thread chooses, and speaks
to the user.

## The delegation contract

A subagent starts blank. It cannot see this conversation, the user's earlier messages, or what you
already tried. Every prompt carries five parts:

1. **Goal** — one sentence, the actual question or change.
2. **Context** — repo paths, the constraint the user stated, what's already been ruled out and why.
   Paste the specifics; don't refer to "the file we discussed".
3. **Boundaries** — what it may change, what it must not touch, whether it may commit or push
   (default: no), and **which repo it works in**. Name it explicitly: a blank subagent does not
   know the scope rule you're under, and "fix this properly" reads to it as permission to go edit
   whatever repo the cause turns out to live in.
4. **Return contract** — the exact shape you want back, with a size cap.
5. **Exclusions** — what *not* to return.

Template:

```
Goal: <one sentence>

Context:
- repo: <abs path>
- <constraint / prior finding / rejected approach, each one line>

Do: <steps or scope>
Do not: <edit, commit, push, touch X>
Do not touch any repo other than the one above — if the fix lives elsewhere, say so and stop.

Return, under 20 lines:
- verdict: <one line>
- evidence: file:line for each claim
- <the 2-3 fields you'll actually use>
Do not paste file contents, full diffs, or logs. Cite file:line and quote at most the
failing line.
```

The return contract is the whole point. Without one, agents send back everything they read and
you've moved the context bloat, not removed it.

## Fan out

Independent work goes in **one message with multiple Agent calls** so it runs concurrently.
Dependent work does not — a second agent that needs the first one's answer waits, and its prompt
carries that answer.

- **Background by default.** Agents run in the background; you're notified when they finish. Set
  `run_in_background: false` only when your very next action needs the result and nothing else
  can usefully happen meanwhile.
- **Never predict a pending agent's result.** If the user asks before the notification lands, say
  it's still running.
- **Parallel writes need isolation.** Two agents editing the same tree corrupt each other. Give
  each `isolation: "worktree"` — or, better, keep the writes in the main thread and let the agents
  only investigate.
- **Cap the fan-out.** 3–6 agents for a normal task. Beyond that the synthesis pass costs more
  than the parallelism saved.

Split work by **subsystem or by question**, not by file — one agent per file means N reports that
all need cross-referencing back in the main thread.

## Pick the type, and pick the model

`Agent` takes both. The type decides what tools it has; the model decides what it costs and how
well it thinks. Choose the type first: `Explore` for read-only search fan-out, `Plan` for
implementation strategy, `general-purpose` / `claude` for anything that writes.

Then the model — `model: "haiku" | "sonnet" | "opus" | "fable"`, which overrides whatever the agent
definition defaults to. **Match it to whether the agent is gathering or judging:**

| | Work | Model |
|---|---|---|
| **Gathering** | Searching, reading many files to answer one question, collecting call sites, summarising a long log | Cheap. The judgement stays with you; the agent's job is to compress |
| **Judging** | Reviewing for correctness, choosing between approaches, adversarially verifying a claim, anything you'd act on without re-deriving | Strong. Downgrading here doesn't save money, it moves the error into a report you will trust |

The test is **if this report is wrong, will you notice?** A missed call site announces itself when
the change fails. A plausible-but-wrong "nothing else references this, safe to delete" does not —
it is indistinguishable from the right answer until the damage is done, which is exactly the class
of claim worth paying for.

Fan-out is where the saving compounds: five gathering agents on a cheap model against one strong
orchestrator is the shape this skill is for. Two details worth knowing — omitting `model` takes the
agent definition's own model rather than yours, and `fork` ignores the parameter entirely, since a
fork always inherits the parent's model.

## Follow up, don't respawn

A second `Agent` call starts fresh and pays the whole ramp-up again. `SendMessage` to the agent's
ID or name continues it with its context intact — use it for "now also check X", "the fix broke
test Y", "give me the line number for that third claim". `ListAgents` shows who's reachable.

## Orchestrator hygiene

- **The subagent's report is not shown to the user.** Relay what matters, in your own words. A
  finished agent whose findings you never surfaced is work the user never received.
- **Don't re-read to verify.** Verify *cheaply and narrowly*: read the one line it cited, run the
  one test it claims passes. Re-reading everything it read defeats the delegation.
- **Don't trust blindly either.** Subagent reports can be confidently wrong. Anything load-bearing
  — a number, "the tests pass", "nothing else calls this" — gets one targeted check.
- **Keep the summary, drop the transcript.** After relaying, carry forward the conclusion and the
  pointers, not the report body.
- **Report faithfully.** If an agent failed, returned nothing, or was skipped, say so. Don't paper
  over a gap with a plausible summary.

## Anti-patterns

| Don't | Do |
|---|---|
| "Look into the auth module and report back" | Ask a specific question with a return contract |
| Delegate, then read the same files yourself | Trust the report; spot-check one cited line |
| Paste the agent's full report to the user | Relay the conclusion and what it means |
| One agent per file across 20 files | One agent per question, across the files it needs |
| Respawn for a follow-up question | `SendMessage` to the running agent |
| Let a subagent commit, push, or open a PR | Keep outward-facing actions in the main thread |
| Let a subagent decide to fix it in another repo | Name the one repo in **Boundaries**; a cross-repo cause comes back as a finding |
