---
name: house-style
description: >-
  Bring a project up to the engineering conventions I work by — stack, architecture, tests, and
  the documentation that keeps them honest — and record them in that repo's own CLAUDE.md so the
  next session inherits them instead of re-deriving them. Use when the user says "set up this
  project", "onboard this repo", "write the CLAUDE.md", "document this project for agents", "apply
  my preferences", "what are my conventions", "how do I like things done" or when starting work in
  a repo that has no CLAUDE.md. Reads what the project already does before proposing anything:
  existing code wins on style, and these preferences steer what is newly designed.
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

## The conventions themselves

[`references/principles.md`](references/principles.md) holds them: architecture (structural
invariants, targeted writes, privacy as enforcement, containment in both directions, one copy of the
data, one schema as the contract, depth and seams, explicit environment selection), tests (test-first
with the red verified, public behaviour, triangulation, blind verification, asserting absence,
snapshotting drift surfaces, filling the gap the build doesn't check, network-boundary mocking,
enforced coverage, one runner), order of work on a new project (walking skeleton with green CI,
smoke test from commit #1, day-one logging behind a seam, local first), and documentation
(`CLAUDE.md` vs `TODO.md`, `CONTEXT.md` and ADRs, pointing at authority instead of asserting a
count, keeping corrections, commands that have been run).

**Read it before proposing anything structural.** Step 1 of the procedure loads it.

## Working rules

- **Commit after every chunk that is verified working**, not at the end. Verified means the build,
  test, synth or invoke actually ran and passed.
- **Trunk-based: short-lived branches, draft PR early, a human merges.** Nothing auto-merges.
- **lefthook pre-commit hooks, every command scoped to its own file globs.** Unscoped, the hook runs
  the whole toolchain on a docs-only commit — and then fails on a machine with no `node_modules`, in a
  repo where nothing it checked even changed.
- **Anything billable or deployed needs permission for that exact action; approved once is not
  approved again.** The spending rules themselves are global (`~/.claude/CLAUDE.md`); what this skill
  adds is writing them into the project's own `CLAUDE.md` under hard rules.
- **A job that never runs looks exactly like one that does.** Surface freshness where someone will see
  it — age of the newest backup point, timestamp of the last sync — and treat unreadable, missing and
  empty as three distinct failures rather than one silence. Absence is the state that reports itself
  as fine.
- **A rule that delegates to a mechanism has to check the mechanism exists.** "Use AWS Backup for
  longer retention" was `ja-changelog`'s documented policy for months with nothing implementing it,
  while the repo grew hand-maintained CSVs doing the job. Found by running the command and getting an
  empty list — not by re-reading the sentence.

## The procedure

1. **Read first** — [`references/principles.md`](references/principles.md), then the project:
   layout, how tests run, how the environment is selected, and any existing `CLAUDE.md`, `README`,
   `CONTEXT.md` or ADRs. The codebase wins on style, so you cannot apply this skill without knowing
   what it already does.
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
