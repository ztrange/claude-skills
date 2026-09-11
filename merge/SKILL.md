---
name: merge
description: >-
  Land a pull request safely: check `main` has not moved since the branch was cut, rebase onto it
  and force-push under a pinned lease if it has, read the CI result rather than trusting a tick —
  or the absence of one — then rebase-merge, cut the capability tag in a repo that versions that
  way, and clean up the branch, the primary clone and the worktree. Use when the user says "merge it", "land this", "merge the PR", "ship it", "mergea", or
  "haz merge". Never merges without being told to. Treats the local `HEAD..origin/main` count as the
  authority on whether `main` moved, pins the force-with-lease to a recorded sha because the bare
  form silently clobbers, never lets an empty check rollup or an empty `conclusion` count as a pass,
  and confirms from PR state because `gh`'s own exit code lies here. Tags only a repo that already
  carries version tags, and reads the next number with git's version sort, since lexical sort makes
  `v0.9` outrank `v0.10`.
---

# Merge — land it on a `main` that has not moved under you

**Merge only when the user says to.** Approving one PR is not approving the next, and a green PR is
not an instruction. Saying it in advance counts, and so does "afk": that skill carries a standing
merge permission for whatever the run finishes, so under it this step is already satisfied — every
step after it still applies.

**`main` moving is the default case, not the exception.** Any repo with more than one agent or one
human gains commits between opening a PR and landing it. Every step below assumes it happened and
checks; none of them assume it did not.

## 1. Pre-flight

```bash
gh pr view <n> --json mergeable,mergeStateStatus,state
```

| Value | Meaning |
|---|---|
| `MERGEABLE` / `CLEAN` | Ready |
| `CONFLICTING` / `DIRTY` | Real conflicts — go to step 3, do not force anything |
| `MERGEABLE` / `BLOCKED` | A review or check gate is unmet. Read which; do not merge around it |
| `MERGEABLE` / `UNSTABLE` | Checks failing or pending — step 4 |
| `UNKNOWN` / `UNKNOWN` | **Transient.** GitHub computes mergeability asynchronously. Re-query; never treat it as a failure |

Do **not** rely on `mergeStateStatus: BEHIND` to tell you `main` moved. It only appears when the
repo enables "require branches to be up to date", which most do not. Step 2 is the authority.

## 2. Did `main` move?

```bash
git fetch origin
git rev-list --count HEAD..origin/main     # 0 = up to date, >=1 = behind by that many
```

Both lines matter. Run before the fetch and it reports a stale `0`. Compare against local `main`
instead of `origin/main` and it lies too — in a linked worktree the shared local `main` sits
wherever the primary clone left it, which is not where the remote is.

`0` → skip to step 4.

## 3. Rebase onto it

```bash
git rebase origin/main
```

Exit `0` covers both a replay and `"Current branch <b> is up to date."`. Exit `1` is a conflict:
`"could not apply <sha>"`. Detect a stuck rebase without hardcoding the path — in a worktree it is
not `.git/rebase-merge`:

```bash
test -d "$(git rev-parse --git-path rebase-merge)"   # 0 = mid-rebase
git diff --name-only --diff-filter=U                 # the conflicted files
```

**Conflicts are the user's call.** Resolve only what is mechanical and obvious; otherwise
`git rebase --abort` (which restores the pre-rebase tip exactly) and hand it back with the file
list. A conflict resolved by guessing is a bug with a clean commit message on it.

## 4. Push the rebase — pin the lease

Record the sha **before** any further fetch, and pin it:

```bash
EXPECT=$(git rev-parse origin/<branch>)
git push --force-with-lease=<branch>:$EXPECT origin <branch>
```

**Never use bare `--force-with-lease` here.** It leases against the remote-tracking ref, and any
plain `git fetch` — yours, a tool's, an editor's background poll — silently satisfies it.
Reproduced: a colleague pushed to the branch, bare lease correctly rejected with
`" ! [rejected] (stale info)"`, then one `git fetch` later the same command reported
`"(forced update)"` and their commit was gone from the remote. The pinned form still rejected.

Rejection means someone else moved the branch. Stop and look; do not escalate to `--force`.

## 5. Read the checks — and don't trust the *absence* of a tick either

Every mistake available here has one shape: **an absence of signal read as a positive answer.** A
check that cannot tell "no CI exists" from "CI has not started yet" is not a gate. `[]`, `""` and a
missing key all mean *ask again*, never *pass*.

### 5a. The rollup is the authority

```bash
gh pr view <n> --json statusCheckRollup --jq '
[ .statusCheckRollup[]? | {
    name: (.name // .context),
    done: (if .__typename == "CheckRun" then .status == "COMPLETED"
           else (.state != null and (.state | IN("PENDING","EXPECTED") | not)) end),
    bad:  (if .__typename == "CheckRun"
           then ((.conclusion // "") | IN("FAILURE","TIMED_OUT","CANCELLED","ACTION_REQUIRED","STARTUP_FAILURE","STALE"))
           else ((.state // "") | IN("FAILURE","ERROR")) end) } ]
| {total: length, pending: [.[]|select(.done|not)|.name], failed: [.[]|select(.bad)|.name]}'
```

Merge only on **`total > 0` and `pending == []` and `failed == []`**. `total == 0` is never a pass
— it goes to 5b. Requiring `total > 0` is what stops "0 checks, therefore 0 pending, therefore
done" from satisfying a wait loop.

Why each clause is written that way — the shorthands that look equivalent are not:

- **The two row shapes have disjoint keys**, so a missing key reads as `null` and null-sniffing
  becomes a type test by accident. `gh`'s own export (`api/export_pr.go`) emits, for a **CheckRun**:
  `__typename, name, workflowName, status, conclusion, startedAt, completedAt, detailsUrl` — and no
  `state` at all; for a **StatusContext** (legacy commit status, e.g. an external CI provider):
  `__typename, context, state, targetUrl, startedAt` — no `status`, no `conclusion`, and the name
  lives in `context`. Branch on `__typename`, which is always present.
- **`.conclusion // .state` does not fall through.** jq's `//` falls through on `null` and `false`
  only; an in-progress check run has `conclusion: ""`. Observed on ps-mutuus/mutuus-changelog#52:
  `{"name":"Site typecheck + build","status":"IN_PROGRESS","conclusion":""}` collapses into an
  empty-string bucket that is not `FAILURE` and so reads as fine. Gate on `status` first; look at
  `conclusion` only once `status == "COMPLETED"`.
- **`.state != null` means "this is a legacy status context", not "it finished".** A pending one is
  `state: "PENDING"`. `StatusState` is `EXPECTED ERROR FAILURE PENDING SUCCESS` — only the last
  three are terminal, so `PENDING`/`EXPECTED` must count as pending.
- **`COMPLETED` is the only terminal check-run status.** `CheckStatusState` is
  `REQUESTED QUEUED IN_PROGRESS COMPLETED WAITING PENDING`; five of the six are still running.
- **The failing conclusions are more than `FAILURE`.** `CheckConclusionState` failures are
  `FAILURE TIMED_OUT CANCELLED ACTION_REQUIRED STARTUP_FAILURE STALE`; `SUCCESS`, `NEUTRAL` and
  `SKIPPED` pass.
- An unrecognised `__typename` falls into the `else` branch with no `state` and lands in `pending`.
  That is deliberate: unknown fails closed.

### 5b. An empty rollup means re-query, not "no CI"

`[]` is also what GitHub returns for a minute or two after a force-push, while it re-associates
workflow runs with the new head. Observed on #52 immediately after the step-4 push: the rollup was
`[]` and `gh pr checks 52` printed `no checks reported on the 'claude/gh-path-helper' branch`,
while a `PR checks` run was already queued for that exact head sha. Concluding "no CI" there merges
with CI unrun.

Prove a run exists before concluding one does not:

```bash
HEAD=$(git rev-parse HEAD)
gh run list --branch <branch> --limit 20 --json headSha,status,conclusion,workflowName \
  --jq "[.[]|select(.headSha==\"$HEAD\")]"
```

Non-empty → CI exists; wait, whatever the rollup says. Empty **and** an empty rollup is still not
proof: `gh run list` sees GitHub Actions only, so an external provider that posts commit statuses
appears in neither until it registers. Re-query over a settle window (~60s) before calling it "no
CI", and say in the final report that no-CI was concluded from an absence.

### 5c. The wait loop

```bash
for _ in $(seq 1 60); do
  R=$(gh pr view <n> --json statusCheckRollup --jq '<the 5a filter>')
  T=$(jq -r .total <<<"$R"); P=$(jq -r '.pending|length' <<<"$R"); F=$(jq -r '.failed|length' <<<"$R")
  [ "$F" -gt 0 ] && { echo "failed: $(jq -c .failed <<<"$R")"; break; }
  [ "$T" -gt 0 ] && [ "$P" -eq 0 ] && { echo "all passed"; break; }
  sleep 15
done
```

`T > 0` guards the exit. Without it the loop terminates instantly on the post-force-push `[]`,
which is exactly how a hand-written poll loop passed a PR whose checks had not started.

`gh pr checks <n>` is a hint, not the gate: exit `0` all passed, `1` **either** a failure exists
**or** no checks are configured (the two are indistinguishable from the exit code), `8` pending
(documented, unobserved here). Use the rollup to decide; use `gh pr checks` only for a readable
dump when reporting.

### 5d. Run the gates CI does not — locally, in the PR's worktree

A green rollup only proves what the workflow ran. A repo may keep a gate out of CI on purpose
because it is slow or has no business blocking every commit, and then the merge is the one
moment it has to run. Read the target repo's `CLAUDE.md` for such a gate; do not infer one.

On ztrange/veri it is `make docs-check` (thirty sandboxed builds of `docs/walkthrough.html`,
removed from CI on 2026-09-11 because it made every job ~4× longer on a runner billed by the
minute). Run it when the PR touches `docs/`, `skills/solve-issue/scripts/` or `Makefile`:

```bash
make docs-check          # in the PR's worktree, on the rebased tip
```

Two ways it goes red, with different fixes:

- **The guards fail** — a real defect. Hand it back; do not merge.
- **The page is stale** (`docs/walkthrough.html is stale — run make docs`, or `tags missing
  from the capability index`) — mechanical. Regenerate, commit on the PR branch, push, and go
  back to step 5 for the new head:

```bash
make docs && git add docs/walkthrough.html \
  && git commit -m "docs: regenerate walkthrough (#<n>)" && git push
```

Never regenerate on `main` directly, and never fold the regen into a force-pushed rewrite of
the reviewed commits — it is its own commit, so the page's history says when it caught up.

## 6. Merge

```bash
gh pr merge <n> --rebase --match-head-commit "$(git rev-parse HEAD)"
```

`--match-head-commit` sends the API's `sha` guard, so a branch that moved between step 4 and here
turns into a `409` instead of merging a tip you never reviewed.

Two things `gh` gets wrong in this layout, both expected:

- **Omit `--delete-branch`.** Its local step runs `git checkout main`, which fails with
  `fatal: 'main' is already used by worktree at …` when the primary clone holds `main`.
- **The exit code lies.** That local failure happens *after* the merge has landed. Never retry on
  it. Confirm from state, then delete the remote branch directly:

```bash
gh pr view <n> --json state -q .state        # expect MERGED
git push origin --delete <branch>
```

## 6b. Tag the capability, if this repo versions that way

**Opt-in by existence.** Tag only a repo that already carries tags in this shape. A repo with no
tags has not asked for versioning, and inventing one on its behalf is a decision that is not yours:

```bash
git fetch --tags origin
LATEST=$(git tag --sort=-v:refname | head -1)   # empty => this repo does not version. Stop here.
```

**`--sort=-v:refname`, never `sort` or `sort -r`.** Version sort knows `v0.10 > v0.9`; lexical sort
does not. Observed on ztrange/veri with ten tags present: `git tag | sort | tail -1` answers `v0.9`,
so the next tag computes as `v0.10` — which already exists, and `git tag` then refuses or, worse,
`-f` moves the existing one onto the wrong commit.

**A version means a capability changed.** Bump when the merged range contains a `feat:` or `fix:`
that touched the product; skip the tag when the PR was documentation, tests, refactoring or chore
only, and say in the report that you skipped it and why. Read the range, do not guess:

```bash
git fetch origin && git log --format='%h %s' ${LATEST}..origin/main
```

A `fix:` that only repairs documentation is a documentation PR — the commit type describes the
change, not the thing changed. This is the one judgement in the step.

Then tag the merge result on `main` — not the branch tip, which no longer exists:

```bash
NEXT="v0.$(( ${LATEST#v0.} + 1 ))"
git tag -a "$NEXT" origin/main -m "<the capability, in the issue's own words>"
git push origin "$NEXT"
```

The message is what a reader scans months later, so it states the **capability**, not the change:
"supervisor retries a killed-stuck leaf up to a bounded budget", not "merge PR #13". The issue
title is usually already that sentence.

Backfilling an old tag is the same command plus a retro-date, because an annotated tag's
`creatordate` is the *tagger* date and defaults to now — ten backfilled tags otherwise all claim to
have shipped today:

```bash
GIT_COMMITTER_DATE="$(git log -1 --format=%aI <sha>)" git tag -a v0.N <sha> -m "<capability>"
```

### 6c. Regenerate what derives from the tag

A tag is an input to any build that reads `git tag` — on ztrange/veri the walkthrough's
capability index — and cutting one changes the built output without changing a file, so
`make docs-check` on `main` is now red until someone regenerates. Do it now, as a PR, not as a
push to `main`; the recipe is the repo's (veri: `CLAUDE.md`, "A regen commit built at the tag
isn't the fixpoint"). Skip this in a repo whose docs do not derive from tags.

## 7. Leave the tree as you found it

```bash
git -C <primary-clone> pull --ff-only        # the primary is the only place main advances
git worktree remove <path>                   # once nothing is uncommitted
```

Report the merge commit sha **and the tag**, and say explicitly if anything was skipped — an
unresolved conflict handed back, a check that was pending, a branch left in place, a tag not cut
because the PR carried no capability.

## Limits

- A locally clean rebase does not guarantee the server-side rebase succeeds. If `main` moves
  between step 4 and step 6 the merge can still fail; `--match-head-commit` guards the head, not
  the base. Expect `405 Merge cannot be performed` or `409 head did not match`; re-run from step 2.
- `gh pr checks` exit `8` is documented but was not observed here. Treat any non-`0`, non-`1` exit
  as pending and wait rather than merging.
- The `StatusContext` half of the step-5a filter is derived, not observed: the field list comes from
  `gh`'s `api/export_pr.go` and the terminal/failing values from the `StatusState` GraphQL enum, but
  no live legacy status context has been seen through it. Only the `CheckRun` half is observed
  (ps-mutuus/mutuus-changelog#52, and a 37-row live rollup on cli/cli#14334). If a repo's CI posts
  commit statuses rather than check runs, read the raw rows once before trusting the summary.
