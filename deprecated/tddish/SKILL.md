---
name: tddish
description: >-
  Develop under TDD discipline without any orchestration: find the suite, prove it green, plan the
  change as small behavioural steps, then run Red → Green → Refactor per step — the red predicted
  before it is run and watched to fail for the right reason, the green the minimum the test demands,
  the refactor bounded to the files that cycle touched. Use when the user says "tdd", "tddish", "use
  TDD", "test-driven", "test first", "write the test first", "red green refactor", "do this
  test-first", "start with a failing test", or asks for a change to be developed test-first. One
  worktree, no state machine; the main thread orchestrates per `/delegate` and every suite run and
  cycle happens in a subagent, so test output never grows the main context — for the projects where
  veri's `/tdd` is not installed or not worth its weight. When the request names a GitHub issue, it claims the issue with
  veri's label and ticks a veri-format plan ledger as steps land.
---

# tddish — TDD discipline, nothing around it

**The rigour lives in the order of operations and in what each phase is allowed to touch, not in
machinery.** There is no blind verifier and no bail/revise loop.

**The project wins on convention.** Its runner, its test layout, its naming, its assertion style.
This skill supplies the loop, never the stack.

## Who does what — always through `delegate`

Load the `delegate` skill and follow its contract for every subagent below. Test output, file dumps
and build logs are what fills a TDD session's context; none of it belongs in the main thread.

| Main thread | Subagent |
|---|---|
| Picks the test command (§0.1), claims the issue (§0.4), writes the plan and ledger (§1) | Runs the baseline (§0.2) and the closing full suite (§3), returns counts and failing case names |
| Hands one step to a cycle agent, reads its report, decides go/split/drop/stop | Runs one step's Red → Green → Refactor (§2) in the worktree |
| Verifies narrowly: `git log --oneline -3`, `git show --stat HEAD`, the predicted vs observed red quoted in the report | Reads the code, writes the test and the production code, runs the suites |
| Ticks the issue's acceptance criteria, pushes, opens the PR | — |

- **Always, even for a one-line step.** This overrides `delegate`'s "under ~3 cheap tool calls, do
  it yourself": a run of small steps done inline is exactly how the main context grows unnoticed.
- **One cycle agent per step, sequentially, in the worktree** — no `isolation`, no fan-out. Two
  cycles in parallel would write the same files and break "one writer per worktree". While one
  runs, the main thread does not edit.
- **The cycle agent commits locally, never pushes.** This overrides `delegate`'s "a subagent does
  not commit": the step commit and each refactor commit are the cycle's atomic units, and routing
  each one back through the main thread costs a round trip per transform. Push and PR stay here.
- **Same step, same agent.** A split, a re-prediction or a "go ahead with Refactor" goes back by
  `SendMessage` to the agent that already holds the test in its context, not to a fresh one.
- **Model**: the cycle agent inherits the session's (it writes code you will not re-read); the
  baseline and full-suite runners take `model: "haiku"` (they only count).

The cycle agent's prompt carries, pasted: the repo and worktree path, the step's criterion verbatim,
the narrow and full test commands, the ledger path and line if any, the commit-subject convention,
and §2 of this file by path (`~/.claude/skills/tddish/SKILL.md`, "The cycle") as its rules. Its
return contract, under 20 lines:

```
step: <criterion>
red: predicted <failure|error: message> / observed <failure|error: message> — match|diverged
green: <covering suites run> → <pass/fail counts>
commits: <sha subject> per commit, step commit first, refactor commits after
reverted: <transform, why> or none
owed: <overfit noted for a later step> or none
stop: <why the user is needed> or none
```

A `stop`, a `diverged` it could not resolve, or a red that passed comes back to the main thread
as a decision — the agent does not drop, split or re-phrase a step on its own.

## 0. Before the first cycle

1. **Name the test command out loud, and say where it came from.** In order: `.veri/test-command`'s
   first non-empty line, a test command stated in the repo's `CLAUDE.md`, then the obvious one from
   the manifest (`package.json` scripts, `Makefile`, `pyproject.toml`). **Nothing matched → ask.** A
   guessed command that runs a subset looks exactly like a green suite.
2. **Run it before changing anything**, in a subagent that returns counts and the names of failing
   cases only. A red baseline is a finding, not a starting point: report
   which cases fail and ask whether to repair them first. Developing on a red suite means no phase
   below can tell its own failure from the inherited one.
3. **Work in a worktree and branch**, per the global prompt. Nothing in this skill merges.
4. **Claim the issue, when the request names one** — before the baseline of item 2. If the issue
   carries the opt-in label (`$VERI_LABEL`, default `ready-for-agent`), swap it for `taken:<lane>`,
   `<lane>` being the text after the label's last `:`, or `main` when it has none:
   ```
   gh issue edit <n> --remove-label "$label" --add-label "taken:$lane"
   ```
   This is what veri's `unlabel-issue.sh` does, so veri's `solvable-issues.sh` stops listing it.
   `gh` refuses a label the repo does not have yet — create it once with `gh label create
   "taken:$lane"`. **No opt-in label → no claim**: say so and carry on; it is not this skill's to
   take, and an issue already `taken:*` by another lane is someone else's run — stop and ask.

   **`taken:<lane>` means in development — claim when that issue's baseline starts, never ahead.**
   Under a concurrency cap, an issue waiting for a slot stays on the opt-in label; "claim them all"
   means take each as a slot frees. An issue whose PR waits to merge keeps `taken:<lane>` until the
   merge closes it, but does not count against the cap. Release an unstarted claim with
   `gh issue edit <n> --remove-label "taken:$lane" --add-label "$label"`.

## 1. Plan the change as behavioural steps

Write the steps where the user can see them — the task list, or the draft PR body.

**When the request names issue `<n>`, the plan is also a ledger**, in veri's format and at veri's
path, so a real veri run could resume the same branch:

```
# Plan for #<n> — <issue title>

- [ ] <behaviour, one cycle's worth> ⟦criterion k⟧
- [ ] <a gap step no acceptance criterion covers>
```

`k` is the 1-based position of the checkbox in the issue's `## Acceptance criteria` it serves; a
gap step carries none. Commit it before the first Red: `plan: scope #<n> into <k> steps (#<n>)`.
`.tdd/` is often gitignored — `git add -f .tdd/issue-<n>.md`. No issue → no ledger.

- **Each step is one externally observable behaviour**, phrased as the criterion a test will pin:
  "rejects a payload whose `amount` is negative", not "add validation" and not "write the validator
  class". If you cannot say what would be observed, it is not a step yet.
- **Smallest step that is still a behaviour.** A step whose Red needs three new collaborators is two
  steps.
- **A step that turns out too big mid-cycle gets split**, not pushed through. Reset the uncommitted
  work, replace the step with the smaller ones, say so, continue.

## 2. The cycle — per step, in this order

This section is the cycle agent's rulebook; "you" below is that agent.

### 🔴 Red — one failing test, no production code

- **Exactly one new test case**, pinning this step's criterion and nothing else.
- **Behaviour, not mechanism.** Assert what the caller observes. No call counts, no private-field
  reads, no timings — a test that describes the implementation breaks on the refactor it was meant
  to protect.
- **No production code in this phase.** Not a stub, not a signature, not an empty class to make the
  import resolve. **The subject not existing yet is a legitimate red** — `ImportError: cannot import
  name 'split_cents'` is this step's failure, reported by most runners as an *error* rather than a
  failure. Predict which of the two you will get; "1 error" where you predicted "1 failure" is a
  divergence like any other.
- **Predict the failure first.** Before running, state what you expect to see — which assertion,
  which message, failure or error. Then run only the suite holding the case, against unmodified
  code. **That narrow command is usually not the configured one** — `.veri/test-command` holds a
  whole-suite invocation, and its flags may not even be legal on the single-module form (`python3 -m
  unittest discover -s tests -t .` → `python3 -m unittest tests.test_split`). Derive it from the
  runner; a run that dies on its own arguments has told you nothing.
  - **It failed as predicted** → Green.
  - **It failed differently** → your model of the code is wrong. Read, do not patch. Fix the
    understanding, re-predict, re-run. A red you did not predict is worth more than a green.
  - **It failed by accident, not by the criterion** — a typo, a missing fixture, an import naming
    the wrong module, a bad command line → that is not this step's red. Fix it and run again. The
    test is `assert`ing nothing yet, so this costs only a re-run; mistake it for the red and you
    commit a green that was never earned.
  - **It passed** → the criterion is already satisfied by code that exists. **Do not weaken the test
    to make it fail.** Either the step is redundant (say so, drop it) or the criterion was wrong
    (re-phrase it and start the Red again).
  - **It cannot be pinned as a lightweight behavioural test at all** → say so and stop for the user.
    A criterion is not re-phrased into whatever happens to be testable.
- **Keep it cheap and self-contained.** Costly dependencies replaced unless the behaviour under test
  *is* the dependency; the case never runs another suite and never re-runs its own.

### 🟢 Green — the minimum that passes

- **The least production code that turns that case green.** No generality the test does not demand,
  no error handling nobody asked for, no second case handled in advance.
- **"Least" means the simplest code that expresses the criterion, not the shortest text that
  satisfies the assertion.** For "splits 900 three ways into [300, 300, 300]", that is
  `[total // ways] * ways` — not `return [300, 300, 300]`, which passes, is genuinely smaller, and
  pins nothing. A constant return is not a step; it buys a cycle of ceremony and leaves the next
  test to do all the work. Write the obvious implementation of *this* criterion and let it stay
  wrong for the criteria no test has stated yet.
- **The test is untouched.** Editing the test in Green moves the goalposts; if the test is genuinely
  wrong, go back to Red and say why.
- **Run the suites covering what you changed**, not just the one case. A green case over two reds
  elsewhere is not a green step.
- **Commit here, one commit per step**, with the criterion in the subject — `feat: rejects a
  negative amount`. This is the step's atomic unit: before this commit the step does not exist, and
  after it the behaviour is pinned.
- **With a ledger, tick the step in this same commit** (`- [ ]` → `- [x]` on its line), never in a
  commit of its own. Once every step carrying `⟦criterion k⟧` is ticked, the main thread — not the
  cycle agent, since it writes to GitHub — ticks the k-th checkbox under the issue's `## Acceptance
  criteria` too: read the body with `gh issue view <n> --json body -q
  .body`, flip that one box, write it back with `gh issue edit <n> --body-file -`.

### 🧹 Refactor — bounded, behaviour-preserving, separately committed

- **Bounds are the source files this cycle touched.** `git show --name-only HEAD` is the list, minus
  what is not code — the step commit may also carry a config file, a fixture, a lockfile. Tidying
  outside that list is a different change and belongs in a different PR.
- **Structural before cosmetic**, and cosmetic usually not at all: a duplicated branch, a name that
  lies, a seam missing where the step kept reaching through — those pay. Reformatting does not.
- **One commit per transform**, `refactor: <what>`, so a break stays attributable.
- **Run the covering suites after every transform.** Red → **revert that transform**, do not chase
  it green. A behaviour-preserving change that changes behaviour was not the refactoring you
  thought it was.
- **No test file is edited in this phase.** Touching a test here removes the only thing checking the
  refactor.
- **Generality comes only from triangulation.** Overfit code — a hardcoded return, a special case
  the one test happens to accept — is not hand-generalized here. Either the next step's test forces
  it, or you note it as owed and move on. A general implementation nothing tests is worse than an
  obvious special case.

Then back to the next step's Red.

## 3. Closing the change

- **Run the full suite**, not the narrow one, before pushing — in a subagent, counts only. Report
  the counts.
- **A step you dropped, split or could not test is named in the PR body** with why — the plan was
  visible, so its deviations are too. With a ledger, the same goes for an unticked line.
- Branch → push → draft PR, per the global prompt. **This skill never merges.**

## What it deliberately does not do

veri's `/tdd` (`ztrange/veri`, `skills/tdd/`) does all of this and carries, additionally: a
conductor process driving subagent leaves, blind verification of every phase by an agent that never
saw the author's reasoning, the ledger as the run's source of truth (resume, refactor-pending
marks), an event log with per-step cost budgets, a bounded revise loop with bail causes, and
GitHub-issue orchestration — issue comments per phase, a WIP draft PR opened at plan time, metrics.
**None of that is here.** Borrowed, and only when the request names an issue: the claim label and
the ticked ledger — written for the user and for a later veri run, never read back by this skill.

That machinery buys verification you cannot rubber-stamp and a run that survives its own
context; it costs a per-repo install, a worktree per issue and a lot of leaf-seconds.

The subagents here are not that: the main thread delegates to keep its context small, not to get
an independent check, and it hands each cycle agent the plan it wrote.

So the honest trade this skill makes: **the cycle agent checks its own work.** The prediction step in Red
is the cheap stand-in — a red you called in advance is harder to fool yourself with than one you
rationalize afterwards — and it is not equivalent. When the change is load-bearing enough that
self-verification is not good enough, use veri, or ask for a second opinion through `delegate`
(a subagent given the test and the criterion, never the reasoning).

## When TDD is not the right loop

Say which of these applies rather than performing the cycle hollowly:

| Situation | Instead |
|---|---|
| Exploring an unfamiliar API | Spike first, throw it away, *then* step 1 |
| A pure refactor, no behaviour change | There is no red to write. Prove the behaviour is covered first — mutate the code you are about to move and watch the suite go red — then transform |
| Config, docs, dependency bump | No test to write. Say so |
| A bug with no reproduction | The reproduction *is* the red. Write it before touching anything |
