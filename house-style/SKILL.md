---
name: house-style
description: >-
  Bring a project up to the engineering conventions I work by — stack, architecture, tests, and the
  documentation that keeps them honest — and record them in that repo's own CLAUDE.md so the next
  session inherits them instead of re-deriving them. Use when the user says "set up this project",
  "onboard this repo", "write the CLAUDE.md", "document this project for agents", "apply my
  preferences", "what are my conventions", "how do I like things done", "configura este proyecto", or
  when starting work in a repo that has no CLAUDE.md. Reads what the project already does before
  proposing anything: existing code wins on style, and these preferences steer what is newly designed.
---

# House style — the conventions, and where they get written down

**The codebase wins on style.** These apply to seams being newly designed and to arguments about
direction. Not a mandate to migrate working code; an unrequested refactor is not an application of
this skill. The procedure at the end puts them in the project's own `CLAUDE.md`, so this fires once
per repo rather than once per session.

## Stack, when the choice is actually open

A preference, not a requirement — a client's existing stack settles it, and so does a constraint
this skill cannot see.

| | Default | Notes |
|---|---|---|
| Cloud | AWS | |
| Compute | Serverless first | Lambda over anything with a server to keep warm |
| IaC | CDK, in TypeScript | Observed exception: `expense-tracking` picked SST v3 to get out of CloudFormation — a deliberate ADR, not drift |
| Language | TypeScript everywhere, `strict: true` | |
| UI | Whatever is current | Deliberately unnamed |
| Packages | pnpm; workspaces the moment there are two | `apps/*`, one lockfile, tooling configured once at the root |
| Lint + format | Biome | One tool, one pass, one config. ESLint + Prettier only where a repo already runs them or needs a plugin Biome lacks |
| Unit + component | Vitest + React Testing Library | The one runner |
| Acceptance / E2E | Playwright | A different layer, not a second runner |
| Network in tests | MSW | |
| Contracts | Zod, types inferred | See *one schema is the contract* |
| Git hooks | lefthook | |

**Every name in that table is expected to age.** Current as of **2026-08**; UI turns over fastest
(hence unnamed), tooling slower but not never. They are suggestions to verify, not settled facts:

- **Check the row is still the standard** before applying it. This file cannot know what happened
  after it was written; its date is there so you can judge how much could have.
- **If something genuinely replaced it, use the newer one.** A stale default applied because it was
  written down is the failure this table would otherwise cause.
- **The bar is "has won", not "is newer."** Go by what new projects in that ecosystem reach for, not
  what is loudest this quarter — churning the stack every session costs more than an out-of-date row.
- **Say so, so the row can be fixed**: name the row, what it says, what replaced it, the evidence.
  **Don't rewrite the row yourself** — these are the user's own recorded preferences, and a table
  that quietly edits itself is one they can no longer trust.
- **Couldn't check → say the pick is unverified.** Silence reads as confirmation.

So don't take a framework name from this file. `expense-tracking` went React + Vite + TanStack Query
+ shadcn/ui; that is the shape, not the answer. Record the pick and the date in the project's
`CLAUDE.md`, and as an ADR if it was a real trade-off.

## Architecture

- **Make the invariant structural, not documented.** A comment warning callers what to remember is a
  bug with a note attached. Prefer the shape where the mistake cannot be expressed: an operation that
  names what it changes rather than taking an options bag, so there is no field a caller can omit. A
  load-bearing rule enforced only by prose is the thing to fix.
- **Targeted writes over full replaces** at every persistence seam. Read-edit-put makes every field
  the caller's problem, and the first one who forgets a field drops it silently — while a test
  asserting "the row still looks right" passes anyway.
- **Privacy is the enforcement.** A layer that asks not to be bypassed is a convention, and
  conventions lose. Don't re-export the raw client from the repository index: a route that cannot
  *name* the table cannot issue its own query.
- **Containment runs both ways.** Stopping callers reaching in is half a seam; the other half is the
  implementation's vocabulary not leaking out. `ja-changelog` held the outbound half while ten route
  files each tested a raw AWS error name — four dialects for "the conditional write lost". The
  guarded writer raises what its condition *means*, because only the writer knows what it asserted:
  the same driver error is a 409 on one write, a 404 on another, a 410 on a third.
- **One copy of the data.** A second copy of a judgement competes with it, and a stale copy is worse
  than none. Where something a person decided cannot be re-derived, that argues for retaining the
  real store, not for a hand-maintained mirror.
- **Configuration that steers nothing is worse than none** — a value no code reads will be trusted by
  the next person. Either wire it, or say where it is displayed that it is inert.
- **One schema is the contract; types derive from it.** Not a hand-kept type beside a hand-kept
  validator beside a hand-kept OpenAPI file. In `expense-tracking` the Zod schemas in `shared` are
  the source: the server validates with them, docs generate from them, the frontend imports the
  inferred types. Test in any language: *can two copies of this contract disagree?* Fixtures and mock
  handlers build from the schemas too — a hand-written fixture is a third copy, and it drifts first.
- **Depth, seams and adapters**, in that vocabulary — call the Skill tool with `"codebase-design"`
  for the glossary rather than paraphrasing it. One adapter means a hypothetical seam; two mean a
  real one.
- **Environment is selected by explicit input, and the tooling refuses the wrong one.** The deploy
  path fails closed when the target is missing or mismatched rather than defaulting to something
  plausible.
- **Siblings don't import each other.** A layout deliberately two things stays two things; each owns
  its manifest, and the coupling is a path, not an import.

## Tests

**Test-first, and the test has to earn it.** Red before green, and the red has to fail *for the right
reason* — not a typo, a missing import, or an unwired fixture. A test nobody has watched fail is not
known to test anything.

- **Assert public behaviour, not internals.** A test reaching past the interface describes the
  implementation and breaks on the refactor that was supposed to be safe.
- **Generality comes from triangulation.** Don't write the general solution because you can see it;
  let the next case force it. The shortcut is how you get a general implementation nothing tests.
- **Spend behaviour specs on rule-dense modules** — simple inputs and outputs, a lot of logic
  between. A spec on a pass-through is ceremony.
- **Verification that cannot rubber-stamp.** Whatever confirms the test is honest should not have seen
  the reasoning that produced it — the `veri` idea, where a blind leaf gets the test and the spec but
  never the author's justification.
- **Assert the absence when the bug is an omission.** Where the failure is "a field got dropped" or
  "the write went out the old way", assert it does *not* happen. A positive assertion about the end
  state passes happily on the day the caller happened to remember.
- **Snapshot the surface that drift attacks** — the route table with its auth tier, the public
  exports — and derive counts from it with a command instead of restating them in prose. Two people
  each correctly adding one still merge to a wrong total.
- **Know what the build does not check, and put a test in the gap.** Packaging proves packaging, never
  that the code runs. Where a directory ships as-is with no bundler and no typecheck, a misspelled
  relative import synths clean, deploys green and 500s at cold start — so one test that imports the
  real module graph and asserts the entry point is a function stands between a typo and an outage.
- **A migration has an oracle.** Replacing a system: the old one's output is the acceptance test —
  same inputs, same numbers, and the diff is the bug list.
- **Mock at the network boundary, not at the client.** MSW intercepts the transport, so the code under
  test uses its real client, serialisation and error paths; stubbing the client tests the stub. **No
  test reaches a real service**, and a test that needs one is telling you the seam is missing.
- **A coverage number nothing enforces is decoration.** v8 coverage with a threshold that fails CI,
  set where the suite actually is and raised deliberately; a comfortable number teaches the team to
  route around it.
- **One runner, layers above it.** Vitest for unit and component; Playwright is the acceptance layer,
  split off by what it proves — a real browser, real navigation — not by taste. A second runner in the
  *same* layer is a cost with no payer; where a project already has one, follow the project.

## Order of work on a new project

- **A walking skeleton with green CI before any feature.** The whole pipeline — typecheck, lint, test,
  build, e2e — passing on an empty app, first commit. Until green is reachable a failing test is
  ambiguous: nobody can tell the red you wrote from the red the pipeline was already in, and
  red-before-green stops meaning anything.
- **The skeleton carries the smoke test** — the one that imports the real entry point and asserts it
  loaded, present from commit #1 rather than after the first cold-start 500.
- **Logging is day-one work, behind a seam.** Structured logs (pino is the current pick) through one
  module the app calls, not `console.log` at call sites. Logging added after an incident is designed
  by hindsight. Put the error-tracker and telemetry adapter in at the same time, dormant — the seam is
  what makes activating it a config change.
- **Local first while requirements are still moving.** Run the whole thing on the machine behind
  storage and config seams; add the cloud adapter when a real need forces it. The default is still AWS
  and serverless — this is about *when*, not *whether*. The local and cloud adapters are also what
  make that seam real rather than hypothetical. Record the deferral as an ADR, so the next reader
  finds a decision rather than an omission.

## Documentation

- **`CLAUDE.md` is what exists and why** — what you would otherwise learn by breaking something. Not
  the queue: unfinished work and decisions waiting on a human go in `TODO.md`. A TODO that accumulates
  finished work stops being read; a CLAUDE.md that accumulates plans stops being trusted.
- **The glossary is `CONTEXT.md`, and it lands before the first feature.** Decisions go in
  `docs/adr/` — the ones from a real trade-off that would look arbitrary without it. Call the Skill
  tool with `"domain-modeling"` when either needs work.
- **A line that can go stale points at its authority instead of asserting the value.** Not "nine gated
  routes" but "read the count off the route snapshot", with the command. Any count in prose is a claim
  that will be wrong later and confidently cited in the meantime.
- **Keep the corrections, with the reasoning that made them plausible.** A wrong symbol invites a
  correction; a wrong symbol with a convincing rationale invites someone to change the code to match.
- **Commands in the file have been run**, from the directory the line names, doing what it claims.

## Working rules

- **Commit after every chunk that is verified working**, not at the end. Verified means the build,
  test, synth or invoke actually ran and passed.
- **Trunk-based: short-lived branches, draft PR early, a human merges.** Nothing auto-merges.
- **lefthook pre-commit hooks, every command scoped to its own file globs.** Typecheck on
  `*.{ts,tsx}`, format on what that formatter owns. Unscoped, the hook runs the whole toolchain on a
  docs-only commit — and then fails on a machine with no `node_modules`, in a repo where nothing it
  checked even changed.
- **Anything billable or deployed needs permission for that exact action; approved once is not
  approved again.** The spending rules themselves are global (`~/.claude/CLAUDE.md`) — CI on
  `ubuntu-latest`, `timeout-minutes` on every job, cron frequency as a cost decision. What this skill
  adds is that they are written into the project's own `CLAUDE.md` under hard rules.
- **A job that never runs looks exactly like one that does.** Surface freshness where someone will see
  it — age of the newest backup point, timestamp of the last sync — and treat unreadable, missing and
  empty as three distinct failures rather than one silence. Absence is the state that reports itself
  as fine.
- **A rule that delegates to a mechanism has to check the mechanism exists.** "Use AWS Backup for
  longer retention" was `ja-changelog`'s documented policy for months with nothing implementing it,
  while the repo grew hand-maintained CSVs doing the job. Found by running the command and getting an
  empty list — not by re-reading the sentence.

## The procedure

1. **Read first** — layout, how tests run, how the environment is selected, and any existing
   `CLAUDE.md`, `README`, `CONTEXT.md` or ADRs. The codebase wins on style, so you cannot apply this
   skill without knowing what it already does.
2. **Write the project's `CLAUDE.md`**, updating in place if one exists — never overwrite:

   | Section | Holds |
   |---|---|
   | What this is | One paragraph, plus the shape of the system |
   | Layout | Table: path → what it is, and what owns it |
   | Jump-points | The handful of `file:line` you always end up hunting for |
   | Commands | Ones you ran, with the directory they run from |
   | Conventions | Commit style, language split, naming |
   | Hard rules | What costs money or breaks production |
   | Key technical facts | Why the non-obvious choice was made, so it isn't "simplified" back |

3. **Don't duplicate the global prompt.** `~/.claude/CLAUDE.md` already carries how to write, the git
   and PR rules, spending, repo scope and the verification standard. Restating them dilutes what is
   actually repo-specific.
4. **Record divergences instead of migrating them.** Where the project does something differently,
   write it down as this repo's convention, with the reason if you can find one. That is what stops
   the next session re-litigating it.
5. **It ships like code** — on a branch, in a PR, in the same change as the behaviour it describes.
