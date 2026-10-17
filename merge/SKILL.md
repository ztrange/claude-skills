---
name: merge
description: >-
  Land a pull request safely: check `main` has not moved since the branch was cut, rebase and
  force-push under a pinned lease if it has, read the CI result rather than trusting a tick — or the
  absence of one — mark a draft ready and re-read the checks that readying can start, then
  rebase-merge, cut the capability tag in a repo that versions that way, and clean up the branch, the
  primary clone and the worktree. Use when the user says "merge it", "land this", "merge the PR",
  "ship it", "mergea", or "haz merge". Never merges without being told to.
---

# Merge — land it on a `main` that has not moved under you

**Merge only when the user says to.** Approving one PR is not approving the next; a green PR is not an
instruction. Saying it in advance counts, and so does "afk" — that skill carries a standing merge
permission for whatever its run finishes, satisfying this step and nothing after it.

**And only in the project repo.** A PR in any other repo is not covered by "merge it", is not covered
by `afk`, and does not merge until they say so for that PR. Before step 1, check `gh pr view <n>`'s
repo is the session's own: `gh` happily acts on another via `-R` or from a different directory.

**`main` moving is the default case**, not the exception. Every step assumes it happened and checks.

## 1. Pre-flight

```bash
gh pr view <n> --json mergeable,mergeStateStatus,state
```

| Value | Meaning |
|---|---|
| `MERGEABLE` / `CLEAN` | Ready |
| `CONFLICTING` / `DIRTY` | Real conflicts — step 3, force nothing |
| `MERGEABLE` / `BLOCKED` | A review or check gate is unmet. Read which; don't merge around it |
| `MERGEABLE` / `UNSTABLE` | Checks failing or pending — step 5 |
| `UNKNOWN` / `UNKNOWN` | **Transient** — mergeability is computed asynchronously. Re-query; never a failure |

`mergeStateStatus: BEHIND` does **not** tell you `main` moved — it appears only when the repo requires
branches to be up to date, which most don't. Step 2 is the authority.

## 2. Did `main` move?

```bash
git fetch origin
git rev-list --count HEAD..origin/main     # 0 = up to date, >=1 = behind by that many
```

Both lines matter: before the fetch it reports a stale `0`, and against local `main` it also lies —
in a linked worktree the shared local `main` sits wherever the primary left it. `0` → step 5.

## 3. Rebase

```bash
git rebase origin/main
```

Exit `0` covers a replay and `"Current branch <b> is up to date."`; exit `1` is a conflict,
`"could not apply <sha>"`. Don't hardcode the state path — in a worktree it isn't `.git/rebase-merge`:

```bash
test -d "$(git rev-parse --git-path rebase-merge)"   # 0 = mid-rebase
git diff --name-only --diff-filter=U                 # the conflicted files
```

**Conflicts are the user's call.** Resolve only the mechanical and obvious; otherwise
`git rebase --abort` (which restores the pre-rebase tip exactly) and hand back the file list.

## 4. Push the rebase — pin the lease

```bash
EXPECT=$(git rev-parse origin/<branch>)
git push --force-with-lease=<branch>:$EXPECT origin <branch>
```

**Never bare `--force-with-lease`.** It leases against the remote-tracking ref, and any plain
`git fetch` — yours, a tool's, an editor's background poll — silently satisfies it. Reproduced: a
colleague pushed, the bare lease correctly rejected with `(stale info)`, then one `git fetch` later
the same command reported `(forced update)` and their commit was gone. The pinned form still
rejected. Rejection means someone moved the branch: stop and look, never escalate to `--force`.

## 5. Read the checks — and don't trust the *absence* of a tick either

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

Merge only on **`total > 0` and `pending == []` and `failed == []`**. `total == 0` is never a pass — it
goes to 5b.

**Do not rewrite this filter.** Every clause defends against a shorthand that looks equivalent: the
two row shapes have disjoint keys, `.conclusion // .state` does not fall through because an
in-progress run has `conclusion: ""`, `.state != null` means "legacy status context" and not
"finished", and an unknown `__typename` deliberately lands in `pending`. Field lists, the four
GraphQL enums and the observed incidents are in `references/checks.md` — read it before touching the
filter or when a row looks wrong.

### 5b. An empty rollup means re-query, not "no CI"

`[]` is also what GitHub returns for a minute or two after a force-push, while it re-associates
workflow runs with the new head. Concluding "no CI" there merges with CI unrun. Prove a run exists
before concluding one does not:

```bash
HEAD=$(git rev-parse HEAD)
gh run list --branch <branch> --limit 20 --json headSha,status,conclusion,workflowName \
  --jq "[.[]|select(.headSha==\"$HEAD\")]"
```

Non-empty → CI exists; wait, whatever the rollup says. Empty **and** an empty rollup is still not
proof, since `gh run list` sees GitHub Actions only. Re-query over a ~60s settle window before
calling it "no CI", and say in the report that no-CI was concluded from an absence.

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

`T > 0` guards the exit; without it the loop terminates instantly on the post-force-push `[]`.

`gh pr checks <n>` is a hint, not the gate: exit `0` all passed, `1` **either** a failure **or** no
checks configured — indistinguishable from the exit code. Decide from the rollup; use `gh pr checks`
only for a readable dump when reporting.

### 5d. Run the gates the repo keeps off CI

A green rollup proves only what the workflow ran. A repo may keep a gate out of CI on purpose — too
slow, or no business blocking every commit — and the merge is the one moment it is owed. The
convention is a `merge-gates` make target; run it in the PR's worktree on the rebased tip.

```bash
make -n merge-gates >/dev/null 2>&1 && make merge-gates
```

Exit 0 = every gate it chose to run passed, or none was owed. Non-zero → it printed what failed and,
where mechanical, the fix: do that on the branch as its own commit, push, back to step 5.

## 6. Merge

**Every gate below is an `if … exit 1`, never a comment and never an `&&` chain.** Each block runs as
its own shell, so a gate only stops the block it lives in — which is why 6b, 6c, 7 and 8 each re-read
state. And `set -e` does not abort on a failure to the left of `&&`: that shape merged a PR on a red
rollup in ztrange/veri#55.

### 6a. Ready a draft

`gh pr merge` on a draft fails — silently in some `gh` versions — and nothing earlier un-drafts it.
Observed in ztrange/veri, whose `/tdd` conductor always opens drafts.

```bash
HEAD=$(git rev-parse HEAD)
draft="$(gh pr view <n> --json isDraft -q .isDraft)"
case "$draft" in
  false) ;;
  true)
    before="$(gh run list --commit "$HEAD" --limit 100 --json databaseId -q length)"
    gh pr ready <n>
    draft="$(gh pr view <n> --json isDraft -q .isDraft)"
    if [ "$draft" != "false" ]; then echo "PR <n> is still a draft (isDraft=$draft); not merging" >&2; exit 1; fi
    sleep 30   # let ready_for_review workflows register
    after="$(gh run list --commit "$HEAD" --limit 100 --json databaseId -q length)"
    if [ "$after" != "$before" ]; then echo "readying started new runs ($before -> $after); back to 5c" >&2; exit 1; fi
    ;;
  *) echo "could not read isDraft (got '$draft'); not merging" >&2; exit 1 ;;
esac
```

Readying fires `pull_request: ready_for_review` workflows, so a rollup green a minute ago may not be
the whole story. A new run for the head sha sends you back to 5c, then here — where `isDraft` is now
`false` and the block passes straight through.

### 6b. Merge on a rollup read right now

```bash
HEAD=$(git rev-parse HEAD)
R="$(gh pr view <n> --json statusCheckRollup --jq '<the 5a filter>')"
T=$(jq -r .total <<<"$R"); P=$(jq -r '.pending|length' <<<"$R"); F=$(jq -r '.failed|length' <<<"$R")
if [ "$F" != 0 ] || [ "$P" != 0 ]; then echo "rollup not green (failed=$F pending=$P); not merging" >&2; exit 1; fi
if [ "$T" = 0 ] && [ "${NO_CI_CONCLUDED:-}" != 1 ]; then echo "empty rollup; back to 5b" >&2; exit 1; fi
gh pr merge <n> --rebase --match-head-commit "$HEAD"
```

Re-read here, not carried from 5c, because that loop only `echo`es and `break`s — a loop that ran out,
or broke on a failure, still falls through. An unreadable rollup yields empty `F`/`P`, which is not
`0`, so it fails closed. Set `NO_CI_CONCLUDED=1` only when 5b concluded "no CI", and say so.

`--match-head-commit` sends the API's `sha` guard, so a branch that moved since step 4 becomes a `409`
rather than a merge of a tip you never reviewed.

Two things `gh` gets wrong here, both expected: **omit `--delete-branch`** (its local step runs
`git checkout main`, which fails with `fatal: 'main' is already used by worktree at …` when the primary
holds `main`), and **the exit code lies** — that local failure happens *after* the merge landed, so
never retry on it and never trust it either way.

### 6c. Delete the remote branch — only once state reads `MERGED`

**Deleting a PR's head branch closes the PR.** A draft, a `409`, or a failed merge whose exit code was
ignored all leave it `OPEN`, and an ungated delete turns "not merged yet" into "closed". Observed in
ztrange/veri: a chained delete closed a draft PR that never merged.

```bash
state="$(gh pr view <n> --json state -q .state)"
if [ "$state" != "MERGED" ]; then echo "not merged (state=$state); branch kept" >&2; exit 1; fi
git push origin --delete <branch>
```

Not `MERGED` → stop and report the state. Don't delete, tag, or remove the worktree.

## 7. Tag the capability, if this repo versions that way

**Opt-in by existence.** A repo with no tags has not asked for versioning.

```bash
git fetch --tags origin
LATEST=$(git tag --sort=-v:refname | head -1)   # empty => this repo does not version. Stop here.
```

**`--sort=-v:refname`, never `sort` or `sort -r`.** Version sort knows `v0.10 > v0.9`; lexical does
not. Observed on ztrange/veri with ten tags: `git tag | sort | tail -1` answers `v0.9`, so the next
tag computes as `v0.10` — which already exists, and `git tag` then refuses or, with `-f`, moves the
existing tag onto the wrong commit.

**A version means a capability changed.** Bump when the merged range carries a `feat:` or `fix:` that
touched the product; skip for documentation, tests, refactoring or chore only, and say you skipped it
and why. A `fix:` that only repairs documentation is a documentation PR — the commit type describes
the change, not the thing changed. This is the one judgement in the step.

```bash
git fetch origin && git log --format='%h %s' ${LATEST}..origin/main
```

Then tag the merge result on `main`, not the branch tip, which no longer exists — gated on `MERGED`
like the delete, since an unmerged PR leaves `origin/main` without its commits:

```bash
state="$(gh pr view <n> --json state -q .state)"
if [ "$state" != "MERGED" ]; then echo "not merged (state=$state); no tag" >&2; exit 1; fi
LATEST=$(git tag --sort=-v:refname | head -1)
if [ -z "$LATEST" ]; then echo "no version tags; this repo does not version" >&2; exit 1; fi
NEXT="v0.$(( ${LATEST#v0.} + 1 ))"
git tag -a "$NEXT" origin/main -m "<the capability, in the issue's own words>"
git push origin "$NEXT"
```

The message states the **capability**, not the change: "supervisor retries a killed-stuck leaf up to a
bounded budget", not "merge PR #13". The issue title is usually already that sentence.

Backfilling needs a retro-date, because an annotated tag's `creatordate` is the *tagger* date and
defaults to now — ten backfilled tags otherwise all claim to have shipped today:

```bash
GIT_COMMITTER_DATE="$(git log -1 --format=%aI <sha>)" git tag -a v0.N <sha> -m "<capability>"
```

## 8. Leave the tree as you found it

```bash
git -C <primary-clone> pull --ff-only        # the primary is the only place main advances
state="$(gh pr view <n> --json state -q .state)"
if [ "$state" != "MERGED" ]; then echo "not merged (state=$state); worktree kept" >&2; exit 1; fi
git worktree remove <path>
```

Once 6c has been skipped the worktree is the last copy of an unmerged branch, so it gets the same
gate. `git worktree remove` refuses a dirty tree on its own — never add `--force`. This skill does not
delete the local branch; that is `housekeeping`'s job.

Report the merge sha **and the tag**, and say explicitly what was skipped — a conflict handed back, a
pending check, a branch left in place, a tag not cut because the PR carried no capability.

## Limits

- A locally clean rebase does not guarantee the server-side one succeeds. If `main` moves between
  step 4 and step 6 the merge can still fail; `--match-head-commit` guards the head, not the base.
  Expect `405 Merge cannot be performed` or `409 head did not match`; re-run from step 2.
- Treat any `gh pr checks` exit that is not `0` or `1` as pending and wait.
- The `StatusContext` half of the 5a filter is derived, not observed, and 6a's readying test is blind
  to external providers. Both detailed in `references/checks.md`.
