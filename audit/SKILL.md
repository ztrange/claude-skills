---
name: audit
description: >-
  Read-only whole-repository audit of code quality, security, architecture, maintainability and
  tests, written up as one graded report at `docs/codebase-audit-<YYYY-MM-DD>.md` and opened as a
  PR. Use when the user says "audit", "/audit", "audit this repo", "audit the codebase", "codebase
  audit", "code quality audit", "health check of the code", or asks what state a codebase is in.
  Applies Fran's `manage-complexity`, `refactor` and `test-quality` guidelines by path, fans the
  reviews out as parallel subagents by area, and checks them against a blind second audit.
---

# Audit — a graded, read-only report on the whole repository

An order of operations, not a checklist of its own. The judgement comes from Fran's three skills,
read by path, never copied:

| Guideline | Path | What the reviews take from it |
|---|---|---|
| `manage-complexity` | `/Users/marioferreira/Documents/repos/fc/my-skills/manage-complexity/SKILL.md` | Its four checks: dependency direction, cycles, public surface bloat, scattered invariants |
| `refactor` | `/Users/marioferreira/Documents/repos/fc/my-skills/refactor/SKILL.md` + `guide.md` beside it | Step 1.2 smell scan, the comment audit and the HIGH/MEDIUM/LOW rules. **Never** Step 1.5 (it appends to `BACKLOG.md`) or Phase 2 (it edits code) |
| `test-quality` | `/Users/marioferreira/Documents/repos/fc/my-skills/test-quality/SKILL.md` | Its three checks: redundant tests, weak assertions, test-to-impl coupling |

**If any of those three files is missing, stop and name the missing path.** No fallback to
built-in guidance: a report that claims Fran's guidelines without them is false. Never use the
`*-pass` twins (`complexity-pass`, `refactor-pass`, `test-quality-pass`) — they commit fixes.

**Read-only.** Nothing in the audited repo is edited, and no test, build, synth, install or
deploy runs. The report file is the only write. Every subagent brief says this, says it may not
commit or push, and says a fix that lives in another repo is reported, not made.

## Steps

### 1. Pin the commit

`git fetch origin` and audit `origin/<default branch>`'s HEAD in a fresh worktree on a new branch
`audit/<YYYY-MM-DD>` — never the primary clone, never uncommitted local work. Record the short sha;
every `file:line` in the report is of that sha. Fail loudly on anything other than the repo this
session started in: auditing another repo is reading, but its report branch and PR are writes
there, so ask first.

### 2. Detect the areas and measure the size

From the directory layout and manifests (`package.json` workspaces, `pyproject.toml`, `go.mod`,
`Cargo.toml`, `*.csproj`, CDK/Terraform/serverless dirs, CI files), split the repo into **2–4
areas** of comparable weight, each a set of top-level paths — e.g. "frontend", "backend and
infra", "admin and scripts". Never hard-code names; a one-package repo is one area. Tests are
**always a separate area**, wherever they live.

Out of scope everywhere: generated, vendored, lockfiles, symlinks (audit the target where it lives,
if in this repo), and frozen or archived trees (`deprecated/`, `archive/`, `legacy/` that the repo
says is read-only) — list each excluded path under "Not checked".

**Scale to the repo.** Under ~200 tracked source files, or under 20 code modules, use **one** area
review plus the tests review, and skip step 3 (`manage-complexity` itself says it is not worth it
below 20 modules) — say so in "Not checked". A dry run on an 82-file repo cost ~950k subagent
tokens at full width.

Size table: per area, source files and lines from `git ls-files` (exclude generated, vendored,
lockfiles), plus the production-vs-test line split. Measured, never estimated.

### 3. Build the import graph

Only for code (see "Scale to the repo"). One subagent, whole repo, language-detected (static imports; `madge`/`depcruise`-style output if
already installed, else a grep-built graph — install nothing). Return a compact file: module →
imports, the layer order it infers, every cycle, and modules with the most inbound and outbound
edges. Save it to the scratchpad; each review in step 4 gets its path, not its contents.

### 4. Run the reviews in parallel

One read-only subagent per area from step 2, plus one for tests, **all in one message**. Each
applies **all three** guidelines (the tests review leans on `test-quality`, the rest on the other
two). Each review returns, per guideline, which checks it applied and which were not applicable
and why — a guideline silently skipped is what this catches. Plus these lenses Fran's skills don't cover:

- **Correctness and security**: auth applied per route, input validation, secrets, injection,
  concurrency and idempotency on money or state transitions, error paths that swallow failures,
  missing timeouts, logging of personal data.
- **Efficiency**: serial or repeated I/O, scans on request paths, N+1.
- **Deployability and agent autonomy** (any lens with nothing to apply to is reported as n/a,
  not stretched to fit): CI gates, rollback, hand-synced lists, rules in
  `CLAUDE.md` that compensate for something the compiler could enforce.

Brief (per `/delegate`'s contract): the area's paths, the sha (read files at that sha only — no
live config outside the repo, no `~/.claude/`, no memory files; the guideline files are the one
exception), no writes anywhere, not even `/tmp`, the import-graph path, the three
guideline paths with the exclusions above, the read-only rules, and this return contract —

- Findings, each: one-sentence defect, `file:line` (of the sha), severity by the scale below,
  theme, and whether it was **read** (holds on reading the code, never executed) — every finding is, since
nothing runs.
- What is healthy in the area, each with the evidence.
- What was not read line by line.
- Cap: 60 findings, ranked most severe first.

### 5. Get a blind second opinion and verify it

One more subagent audits the **same sha, whole repo, all dimensions**, briefed only with the
read-only rules and the return contract — not the step-4 results, not the guidelines' names. Same model tier as step 4 or higher, never
a smaller one: in the dry run a small model broke the write-nothing rule and its findings were the
ones dropped as wrong.

Then one verifier subagent re-reads **every** second-audit finding at its cited lines and returns
each as `holds` / `wrong` (with the line that disproves it), and in the same pass re-reads every
step-4 High. Drop `wrong`. Number the second audit's survivors `A1…An`.

### 6. Merge, re-grade, write the report

Dedupe across reviews (same `file` and same defect = one finding); a step-4 finding the second
audit also made keeps its `A` id, so agreement shows. Re-grade every finding against the scale
yourself from its claim — reviewers drift; the code was already re-read for every High in step 5. Number the rest `1…n`, group each severity by theme, write
`docs/codebase-audit-<YYYY-MM-DD>.md` on the step-1 branch, commit, push, open the PR. No `docs/`
directory → ask where before creating one. Report back: the PR url, the verdict table, the count
per severity.

## Severity

- **High**: the code misleads, invites a bug, or has already caused a failure.
- **Medium**: a maintenance or operational cost that can be named.
- **Low**: taste, tidiness, or only two occurrences.

## Report shape

```markdown
# Codebase audit: <repo name>

Date: <YYYY-MM-DD>. Commit audited: `<sha>`.

Nothing was modified, and no tests, builds or deploys were run. Static audit built from an
import graph of the whole repository, <N> read-only reviews (<areas>, tests), and a second
independent audit of the same commit whose findings were re-read in the code before being
included (A1 to An). Every finding comes from reading; none was reproduced by running it.

Guidelines used: `/manage-complexity` (…), `/refactor` (smell catalog and severity rules),
`/test-quality` (…).

Severity: <the three lines above>. All paths are relative to the repository root.

## Verdict by dimension
| Dimension | State |   ← one row each: Layering and coupling; Cohesion and abstraction;
                          Correctness and security; Efficiency; Testability (seams in the
                          production code); Test quality (the tests themselves);
                          Deployability; Agent autonomy. State = one word, then the reason;
                          "n/a" when nothing applies.
## Recommended order of work   ← numbered, each citing finding ids and the harm it removes
## Size                        ← the step-2 table, then the production/test split
## High severity               ← ### per theme; each finding: **id. Claim.** mechanism, then
## Medium severity                 "Where: `path:line`"
## Low severity
## What is healthy             ← each with its evidence
## Open question               ← only what the user must decide; "None." if empty
## Not checked                 ← runtime behaviour, unreproduced findings, files not read
                                  line by line, flagged-but-unread counts. Never empty.
```

## Do not

- Run anything that builds, tests, installs or deploys, or edit any file but the report.
- Report a finding without `file:line`, or one the verifier marked `wrong`.
- Read outside the audited sha, except Fran's three guideline files.
- Merge the report PR.
