---
name: tddish
description: >-
  Develop under TDD discipline without any orchestration: find the suite, prove it green, plan the
  change as small behavioural steps, then run Red → Green → Refactor per step — the red predicted
  before it is run and watched to fail for the right reason, the green the minimum the test demands,
  the refactor bounded to the files that cycle touched. Use when the user says "tdd", "tddish", "use
  TDD", "test-driven", "test first", "write the test first", "red green refactor", "do this
  test-first", "start with a failing test", or asks for a change to be developed test-first. One
  agent, one worktree, no subagents, no ledger, no state machine — for the projects where veri's
  `/tdd` is not installed or not worth its weight.
---

# tddish — TDD discipline, nothing around it

**One agent does all of it.** You write the test, you write the code, you run the suite. There is no
conductor, no ledger file, no blind verifier, no bail/revise loop. The rigour lives in the order of
operations and in what each phase is allowed to touch, not in machinery.

**The project wins on convention.** Its runner, its test layout, its naming, its assertion style.
This skill supplies the loop, never the stack.

## 0. Before the first cycle

1. **Name the test command out loud, and say where it came from.** In order: `.veri/test-command`'s
   first non-empty line, a test command stated in the repo's `CLAUDE.md`, then the obvious one from
   the manifest (`package.json` scripts, `Makefile`, `pyproject.toml`). **Nothing matched → ask.** A
   guessed command that runs a subset looks exactly like a green suite.
2. **Run it before changing anything.** A red baseline is a finding, not a starting point: report
   which cases fail and ask whether to repair them first. Developing on a red suite means no phase
   below can tell its own failure from the inherited one.
3. **Work in a worktree and branch**, per the global prompt. Nothing in this skill pushes or merges.

## 1. Plan the change as behavioural steps

Write the steps where the user can see them — the task list, or the draft PR body. **Not a file in
the repo**; there is no ledger here and nothing reads it back.

- **Each step is one externally observable behaviour**, phrased as the criterion a test will pin:
  "rejects a payload whose `amount` is negative", not "add validation" and not "write the validator
  class". If you cannot say what would be observed, it is not a step yet.
- **Smallest step that is still a behaviour.** A step whose Red needs three new collaborators is two
  steps.
- **A step that turns out too big mid-cycle gets split**, not pushed through. Reset the uncommitted
  work, replace the step with the smaller ones, say so, continue.

## 2. The cycle — per step, in this order

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

- **Run the full suite**, not the narrow one, before pushing. Report the counts.
- **A step you dropped, split or could not test is named in the PR body** with why — the plan was
  visible, so its deviations are too.
- Branch → push → draft PR, per the global prompt. **This skill never merges.**

## What it deliberately does not do

veri's `/tdd` (`ztrange/veri`, `skills/tdd/`) does all of this and carries, additionally: a
conductor process driving subagent leaves, blind verification of every phase by an agent that never
saw the author's reasoning, a committed ledger as source of truth, an event log with per-step cost
budgets, a bounded revise loop with bail causes, and GitHub-issue orchestration. **None of that is
here.** That machinery buys verification you cannot rubber-stamp and a run that survives its own
context; it costs a per-repo install, a worktree per issue and a lot of leaf-seconds.

So the honest trade this skill makes: **the agent checks its own work.** The prediction step in Red
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
