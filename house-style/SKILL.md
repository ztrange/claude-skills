---
name: house-style
description: >-
  Bring a project up to the engineering conventions I work by — stack, architecture, tests, and the
  documentation that keeps them honest — and record them in that repo's own CLAUDE.md so the next
  session inherits them instead of re-deriving them. Use when the user says "set up this project",
  "onboard this repo", "write the CLAUDE.md", "document this project for agents", "apply my
  preferences", "what are my conventions", "how do I like things done", "configura este proyecto",
  or when starting work in a repo that has no CLAUDE.md. Reads what the project already does
  before proposing anything: existing code wins on style, and these preferences steer what is
  newly designed.
---

# House style — the conventions, and where they get written down

The principles below hold whatever the stack is. The procedure at the end puts them into the
project's own `CLAUDE.md`, so this fires once per repo rather than once per session.

**The codebase wins on style.** These apply to seams being newly designed and to arguments about
direction. They are not a mandate to migrate working code, and an unrequested refactor is not an
application of this skill.

## Stack, when the choice is actually open

A preference, not a requirement — a client's existing stack settles it, and so does a constraint
this skill cannot see.

| | Default | Notes |
|---|---|---|
| Cloud | AWS | |
| Compute | Serverless first | Lambda over anything with a server to keep warm |
| IaC | CDK, in TypeScript | Observed exception: `expense-tracking` picked SST v3 to get out of CloudFormation — a deliberate ADR, not a drift |
| Language | TypeScript everywhere, `strict: true` | |
| UI | Whatever is current | Deliberately unnamed — see below |
| Packages | pnpm; workspaces the moment there are two | `apps/*`, one lockfile, tooling configured once at the root |
| Lint + format | Biome | One tool, one pass, one config. ESLint + Prettier only where a repo already runs them or needs a plugin Biome hasn't got — not as a new choice |
| Unit + component | Vitest + React Testing Library | The one runner |
| Acceptance / E2E | Playwright | A different layer, not a second runner |
| Network in tests | MSW | |
| Contracts | Zod, types inferred | See *one schema is the contract* |
| Git hooks | lefthook | |

**Every name in that table is expected to age** — they are the current answer, not the permanent
one, and they were current as of 2026-08. The rows turn over at very different speeds: UI fastest,
which is why that one is left unnamed on purpose; the test and tooling picks slower, but not never.
Treat a name that no longer looks right as a name to check, not as a rule to follow — and fix the
row when you find it stale.

**So don't take a framework name from this file.** "The current one" is the preference, so check
what that is now rather than inheriting whatever was true when this was written. `expense-tracking`
went React + Vite + TanStack Query + shadcn/ui; treat that as an example of the shape, not as the
answer. Record the pick and the date in the project's `CLAUDE.md`, and as an ADR if it was a real
trade-off.

## Architecture

- **Make the invariant structural, not documented.** A comment warning callers what to remember is
  a bug with a note attached. Prefer the shape where the mistake cannot be expressed: an operation
  that names what it changes rather than taking an options bag, so there is no argument a caller
  could forget and no field they could omit. Where a load-bearing rule is enforced only by prose,
  that is the thing to fix.
- **Targeted writes over full replaces**, at every persistence seam. Read-edit-put makes every
  field the caller's problem, and the first one who forgets a field drops it silently — while a
  test asserting "the row still looks right" passes anyway.
- **Privacy is the enforcement.** A layer that asks not to be bypassed is a convention, and
  conventions lose. Don't re-export the raw client from the repository index: a route that cannot
  *name* the table is one that cannot issue its own query, and that is a shape rather than a rule.
- **Containment runs in both directions.** Stopping callers from reaching in is half a seam; the
  other half is the implementation's vocabulary not leaking back out. `ja-changelog` held the
  outbound half for months while ten route files each tested a raw AWS error name and invented
  their own meaning for it — four different dialects for "the conditional write lost". The fix is
  that the guarded writer raises what its condition *means*, because only the writer knows what it
  asserted: the same driver error is a 409 on one write, a 404 on another, a 410 on a third.
- **One copy of the data.** A second copy of a judgement does not preserve it, it competes with it
  — and a stale copy is worse than none. Where something a person decided cannot be re-derived,
  that is an argument for retention of the real store, not for a hand-maintained mirror of it.
- **Configuration that steers nothing is worse than no configuration.** A value sitting in the
  config that no code reads will be trusted by the next person to change something. Either wire it
  or say, where it is displayed, that it is inert.
- **One schema is the contract, and types are derived from it.** Not a hand-kept type next to a
  hand-kept validator next to a hand-kept OpenAPI file. In `expense-tracking` the Zod schemas in
  `shared` are the source: the server validates with them, the docs are generated from them, and
  the frontend imports the inferred types. Whatever the language, the same test applies — can two
  copies of this contract disagree? Fixtures and mock handlers build from those schemas too — a
  fixture written by hand is a third copy, and it is the one that drifts first.
- **Depth, seams and adapters**, in that vocabulary — a lot of behaviour behind a small interface,
  and the seam's *location* is its own decision. Call the Skill tool with `"codebase-design"` for
  the glossary rather than paraphrasing it. One adapter means a hypothetical seam; two mean a real
  one.
- **Environment is selected by explicit input, and the tooling refuses the wrong one.** Whatever
  names the target — env var, profile, config file — the deploy path fails closed when it is
  missing or mismatched rather than defaulting to something plausible.
- **Siblings don't import each other.** A layout that is deliberately two things stays two things;
  each owns its manifest, and the coupling between them is a path, not an import.

## Tests

**Test-first, and the test has to earn it.** Red before green: the failing test comes first, and it
has to fail *for the right reason* — not because of a typo, a missing import, or a fixture that was
never wired up. A test nobody has watched fail is not known to test anything.

- **Assert public behaviour, not internals.** The assertion target is what a caller or the UI can
  observe. A test that reaches past the interface is describing the implementation, and it will
  break on the refactor that was supposed to be safe.
- **Generality comes from triangulation.** Don't write the general solution because you can see it;
  let the next case force it. The shortcut here is how you get a general implementation nothing
  tests.
- **Spend the behaviour specs on the rule-dense modules** — the ones with simple inputs and outputs
  and a lot of logic between them. That is where a spec pays for itself; a spec on a pass-through
  is ceremony.
- **Verification that cannot rubber-stamp.** Where it matters, whatever confirms the test is honest
  should not have seen the reasoning that produced it — that is the whole idea in `veri`, where a
  blind leaf gets the test and the spec but never the author's justification.
- **Assert the absence when the bug is an omission.** Where the failure mode is "a field got
  dropped" or "the write went out the old way", assert that it does *not* happen. A positive
  assertion about the end state passes just as happily on the day the caller happened to remember.
- **Snapshot the surface that drift attacks** — the route table with its auth tier, the public
  exports — and derive counts from it with a command instead of restating them in prose. Two people
  each correctly adding one still merge to a wrong total.
- **Know what the build does not check, and put a test in the gap.** Packaging proves packaging,
  never that the code runs. Where a directory ships as-is with no bundler and no typecheck, a
  misspelled relative import synths clean, deploys green and 500s at cold start — so one test that
  imports the real module graph and asserts the entry point is a function is what stands between a
  typo and an outage. Find the equivalent gap in whatever the toolchain is.
- **A migration has an oracle.** When replacing a system, the old one's output is the acceptance
  test: same inputs, same numbers, and the diff is the bug list.
- **Mock at the network boundary, not at the client.** MSW intercepts the transport, so the code
  under test uses its real client, its real serialisation and its real error paths — stubbing the
  client instead tests the stub. **No test reaches a real service**, and a test that needs one is
  telling you the seam is missing.
- **A coverage number nothing enforces is decoration.** v8 coverage with a threshold that fails
  CI. Set it where the suite actually is and raise it deliberately; a number chosen to be
  comfortable teaches the team to route around it.
- **One runner, and layers above it.** Vitest for unit and component; Playwright is the acceptance
  layer, split off by what it proves — a real browser, real navigation — not by taste. That is not
  a second runner. A second runner in the *same* layer is a cost with no payer, and where a project
  already has one, it follows the project.

## Order of work on a new project

- **A walking skeleton with green CI comes before any feature.** The whole pipeline — typecheck,
  lint, test, build, e2e — passing on an empty app, first commit. Until green is reachable, a
  failing test is ambiguous: nobody can tell the red you wrote from the red the pipeline was
  already in, and red-before-green stops meaning anything. Standing the pipeline up later means
  paying for it while also debugging real failures.
- **The skeleton carries the smoke test** — the one that imports the real entry point and asserts
  it loaded. That is the gap-filling test above, present from commit #1 rather than after the
  first cold-start 500.
- **Logging is day-one work, behind a seam.** Structured logs (pino is the current pick) through
  one module the app calls, not `console.log` sprayed at call sites. Logging added after an
  incident is logging designed by hindsight, and it cannot be retrofitted into code that never had
  it. Put the error-tracker and telemetry adapter in at the same time, dormant — it activates when
  there is somewhere to send to, and the seam is what makes that a config change.
- **Local first while the requirements are still moving.** Run the whole thing on the machine,
  behind storage and config seams, and add the cloud adapter when a real need forces it — hosting,
  a second account, something the laptop genuinely can't do. The house default is still AWS and
  serverless; this is about *when*, not *whether*. The local adapter and the cloud one are also
  what make that seam real rather than hypothetical, which is the second adapter finally showing
  up. Record the deferral as an ADR, so the next reader finds a decision rather than an omission.

## Documentation

- **`CLAUDE.md` is what exists and why — what you would otherwise learn by breaking something.**
  Not the queue: unfinished work and decisions waiting on a human go in `TODO.md`. A TODO that
  accumulates finished work stops being read, and a CLAUDE.md that accumulates plans stops being
  trusted.
- **The glossary is `CONTEXT.md`, and it lands before the first feature does.** Decisions go in
  `docs/adr/` — the ones that came out of a real trade-off and would look arbitrary without it. Call
  the Skill tool with `"domain-modeling"` when either needs work.
- **A line that can go stale points at its authority instead of asserting the value.** Not "nine
  gated routes" but "read the count off the route snapshot", with the command. Any count in prose
  is a claim that will be wrong later and confidently cited in the meantime.
- **Keep the corrections, with the reasoning that made them plausible.** When a documented claim
  turns out wrong, record that it was wrong and why it sounded right. A wrong symbol invites a
  correction; a wrong symbol with a convincing rationale invites someone to change the code to
  match it.
- **Commands in the file have been run** — from the directory the line names, doing what it claims.

## Working rules

- **Commit after every chunk that is verified working**, not at the end. Verified means the build,
  test, synth or invoke actually ran and passed.
- **Trunk-based: short-lived branches, draft PR early, a human merges.** Nothing auto-merges.
- **Pre-commit hooks via lefthook, and every command scoped to its own file globs.** Typecheck on
  `*.{ts,tsx}`, format on what that formatter owns, and so on. Unscoped, the hook runs the whole
  toolchain on a docs-only or config-only commit — which then fails on a machine that has no
  `node_modules` installed, in a repo where nothing it was checking even changed. The glob is what
  keeps the hook honest about what the commit touched.
- **Anything billable or deployed needs permission for that exact action.** Approved once is not
  approved again.
- **A job that never runs looks exactly like one that does.** Surface freshness where someone will
  actually see it — the age of the newest backup point, the timestamp of the last sync — and treat
  unreadable, missing and empty as three distinct failures rather than one silence. Absence is the
  state that reports itself as fine.
- **A rule that delegates to a mechanism has to check the mechanism exists.** "Use AWS Backup for
  longer retention" was `ja-changelog`'s documented policy for months with nothing implementing it,
  and the repo quietly grew hand-maintained CSVs doing the job instead. It was found by running the
  command and getting back an empty list — not by re-reading the sentence.

## The procedure

1. **Read first.** Layout, how tests run, how the environment is selected, and any existing
   `CLAUDE.md`, `README`, `CONTEXT.md` or ADRs. The codebase wins on style, so you cannot apply
   this skill without knowing what it already does.
2. **Write the project's `CLAUDE.md`.** Update in place if one exists — never overwrite. The shape
   that works:

   | Section | Holds |
   |---|---|
   | What this is | One paragraph, plus the shape of the system |
   | Layout | Table: path → what it is, and what owns it |
   | Jump-points | The handful of `file:line` you always end up hunting for |
   | Commands | Ones you ran, with the directory they run from |
   | Conventions | Commit style, language split, naming |
   | Hard rules | What costs money or breaks production |
   | Key technical facts | Why the non-obvious choice was made, so it is not "simplified" back |

3. **Don't duplicate the global prompt.** `~/.claude/CLAUDE.md` already carries how to write, the
   git and PR rules, and the verification standard. Restating them dilutes what is actually
   repo-specific.
4. **Record divergences instead of migrating them.** Where the project does something differently,
   write it down as this repo's convention, with the reason if you can find one. That is what stops
   the next session re-litigating it, and why matching the codebase costs nothing later.
5. **It ships like code** — on a branch, in a PR, in the same change as the behaviour it describes.
