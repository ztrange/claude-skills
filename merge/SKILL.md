---
name: merge
description: >-
  Land a pull request safely: check `main` has not moved since the branch was cut, rebase onto it
  and force-push under a pinned lease if it has, read the CI result rather than trusting a tick,
  then rebase-merge and clean up the branch, the primary clone and the worktree. Use when the user
  says "merge it", "land this", "merge the PR", "ship it", "mergea", or "haz merge". Never merges
  without being told to. Treats the local `HEAD..origin/main` count as the authority on whether
  `main` moved, pins the force-with-lease to a recorded sha because the bare form silently
  clobbers, and confirms from PR state because `gh`'s own exit code lies here.
---

# Merge — land it on a `main` that has not moved under you

**Merge only when the user says to.** Approving one PR is not approving the next, and a green PR is
not an instruction.

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

## 5. Read the checks, don't trust the tick

```bash
gh pr checks <n>
```

Exit `0` all passed, `1` a failure exists, `8` pending (documented, unobserved here).

**Exit `1` also means "no checks are configured"** — it prints `no checks reported on the '<b>'
branch` to stderr with empty stdout. Branching on exit `1` alone will read a repo with no CI as a
repo with failing CI. Disambiguate:

```bash
gh pr view <n> --json statusCheckRollup \
  --jq '[.statusCheckRollup[]?|.conclusion // .state]|group_by(.)|map({v:.[0],n:length})'
```

`[]` means no CI gate exists — proceed. Otherwise pass = no `FAILURE` and nothing outside
`COMPLETED`. `.conclusion // .state` is needed because check runs and legacy status contexts expose
different fields.

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

## 7. Leave the tree as you found it

```bash
git -C <primary-clone> pull --ff-only        # the primary is the only place main advances
git worktree remove <path>                   # once nothing is uncommitted
```

Report the merge commit sha, and say explicitly if anything was skipped — an unresolved conflict
handed back, a check that was pending, a branch left in place.

## Limits

- A locally clean rebase does not guarantee the server-side rebase succeeds. If `main` moves
  between step 4 and step 6 the merge can still fail; `--match-head-commit` guards the head, not
  the base. Expect `405 Merge cannot be performed` or `409 head did not match`; re-run from step 2.
- `gh pr checks` exit `8` is documented but was not observed here. Treat any non-`0`, non-`1` exit
  as pending and wait rather than merging.
