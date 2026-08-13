---
name: install-guardrails
description: >-
  Install git hooks that keep the primary clone parked on `main` and push all work into worktrees:
  a `pre-commit` and `pre-merge-commit` that refuse any commit made in the primary clone, a
  `reference-transaction` hook that catches the paths those never see (`cherry-pick`, `revert`,
  `reset --hard`, `--no-verify`), and a `post-checkout` that says so loudly when the primary
  drifts off `main`. Use when the user says "install guardrails",
  "protect main", "prevent commits to main", "stop me committing in the primary clone", "add the
  git hooks", "set up branch protection", or "instala los guardrails". Checks what git already
  enforces before installing anything, verifies by testing the failure path — including that
  `git pull --ff-only` still works — and states plainly where the guardrail can be bypassed.
---

# Install guardrails — the primary clone holds `main`, work happens in worktrees

**The invariant is not "no commits on `main`". It is "nothing is committed in the primary clone."**
The primary has one job: sit on `main` and hold it, so every worktree can branch from it. It does
that job by being the place nothing is committed. Guard the clone, not the branch name.

**Detect the primary clone by structure, never by path.** In the primary, `--git-dir` and
`--git-common-dir` resolve to the same directory; in a linked worktree `--git-dir` is
`<common>/worktrees/<name>`. That makes the hook portable and committable, with no machine-specific
string in it.

**None of this is a security boundary.** `git -c core.hooksPath=/dev/null commit` skips every hook
here. It stops accidents, not intent.

## 1. What breaks when the invariant breaks

Worth stating when installing, because the failure is indirect and people misdiagnose it. A branch
can be checked out in only one worktree at a time. The moment the primary clone drifts onto a
feature branch, `main` is either claimed by something disposable or unavailable, and then:

- every other worktree's `git checkout main` fails with `'main' is already used by worktree at …`
- `gh pr merge --delete-branch` fails its local step **after the merge has already landed**, so the
  exit code says failure while the PR says merged, and the local branch survives

The second one is the expensive one: it invites a retry of a merge that already happened.

## 2. Check what git already enforces

If the primary keeps `main` checked out, git already refuses to put `main` in a second worktree:

```bash
git worktree add /tmp/probe main    # fatal: 'main' is already used by worktree at ...
```

Confirm that in the target repo before writing anything. What it does *not* cover, and the only
reason to install more:

- `git switch --ignore-other-worktrees main` — explicitly opts out
- `git switch --detach main` — takes the commit without claiming the branch
- committing in the primary clone on any branch at all, which git never objects to

## 3. Install the hooks

Two hooks, both keyed on the primary-clone test. `pre-commit` refuses:

```sh
#!/bin/sh
git_dir=$(cd "$(git rev-parse --git-dir)" && pwd)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$git_dir" = "$common_dir" ] || exit 0     # linked worktree: this is where work belongs
echo "  refused: this is the primary clone; it exists to sit on main and hold it." >&2
echo "    git worktree add .claude/worktrees/<task> -b claude/<task> origin/main" >&2
echo "    to update the primary, never merge:  git pull --ff-only" >&2
echo "    if you truly meant this, git commit --no-verify bypasses it." >&2
exit 1
```

`post-checkout` warns when the primary leaves `main`, and **must exit 0**. Exiting non-zero does
not undo the checkout — it reports an error about a switch that already succeeded, which lies in
the one place someone is reading. Args: `$1` old HEAD, `$2` new HEAD, `$3` = 1 for a branch switch.

```sh
[ "$3" = "1" ] || exit 0
# ...same primary-clone test...
branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = main ] || echo "  ⚠ primary clone is on '$branch', not main" >&2
exit 0
```

`pre-commit` does not run for merge commits — git calls `pre-merge-commit` for those, so
`git merge --no-ff` lands on `main` untouched without it. Install the same body under both names.
A squash merge is caught by `pre-commit`, since it ends in an ordinary commit.

On its own this family is bypassed by `--no-verify`, which the error message above states openly —
a guard whose bypass is documented makes the common accident loud without standing between someone
and a deliberate act. Section 4 closes that bypass along with three paths these hooks never see.
Decide which of the two behaviours is wanted before installing both.

## 4. The second mechanism — neither one is enough alone

`pre-commit` never runs for `cherry-pick`, `revert` or `reset --hard`, so all three land on `main`
in the primary clone untouched. Measured: `main` went from 1 commit to 3 with the hooks above
installed. A `reference-transaction` hook catches exactly those, because they are ref updates:

```sh
#!/bin/sh
[ "$1" = prepared ] || exit 0
gd=$(cd "$(git rev-parse --git-dir)" && pwd); cm=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$gd" = "$cm" ] || exit 0
while read -r old new ref; do
  case "$ref" in refs/heads/*) ;; *) continue ;; esac
  [ "$old" = 0000000000000000000000000000000000000000 ] && continue   # branch creation, and worktree add -b
  case "${GIT_REFLOG_ACTION-}" in pull*|merge*|fetch*) continue ;; esac  # remote sync, allowlisted
  echo "  refused: '${GIT_REFLOG_ACTION:-commit}' would move ${ref#refs/heads/} in the primary clone" >&2
  exit 1
done
exit 0
```

**The allowlist is the load-bearing detail.** Testing `GIT_REFLOG_ACTION` for mere presence lets
`cherry-pick` and `revert` straight through — they set it. Only `pull`, `merge` and `fetch` may
move a branch here; everything else, including an unset action (a plain commit), is refused.

Neither mechanism subsumes the other:

| Path | `pre-commit` family | `reference-transaction` |
|---|---|---|
| `git commit` | refused | refused |
| `git commit --no-verify` | **slips** | refused |
| `git commit --amend` | refused | **blind** — fires no ref transaction at all |
| `git cherry-pick` / `git revert` | **slips** — hook never runs | refused |
| `git reset --hard` | **slips** | refused |
| `git merge --no-ff` | refused, via `pre-merge-commit` | refused |
| `git merge --squash` + commit | refused | refused |
| `pull --ff-only`, `worktree add -b`, commit in a worktree | allowed | allowed |

Install all four hooks. Verified together: every refusal above holds and all three permitted
operations work.

Two things this costs, both worth saying out loud when installing:

- **`--no-verify` no longer bypasses.** The escape becomes `git -c core.hooksPath=/dev/null …`,
  which is not discoverable from the error message. Put it in the message.
- **A branch *switch* still cannot be blocked.** Guarding `HEAD` here refuses `git worktree add -b`
  as well: that command and `git switch` present the hook with identical `PWD`, `GIT_DIR`,
  `rev-parse --git-dir` and environment, so there is nothing to discriminate on. `post-checkout`
  warning after the fact remains the only option.

## 5. Where the hooks live

Hooks live in the common git dir, so **one install covers every worktree** of the repo:

```bash
H="$(git rev-parse --git-common-dir)/hooks"
install -m 755 <refuse>  "$H/pre-commit"
install -m 755 <refuse>  "$H/pre-merge-commit"
install -m 755 <reftxn>  "$H/reference-transaction"
install -m 755 <warn>    "$H/post-checkout"
```

To version the hooks instead, keep a tracked `.githooks/` and point git at it — but know the
trade-off: **a relative `core.hooksPath` resolves against each worktree's own top level**, so the
hooks vanish on any branch that doesn't carry the directory. That is usually harmless (the primary
sits on `main`, which has it) and occasionally baffling. An absolute path fires everywhere and is
not committable. Pick deliberately:

```bash
git config core.hooksPath .githooks     # tracked, shared, per-branch, per-clone
```

Either way `core.hooksPath` is **not carried by a clone**. A fresh clone has no hooks until someone
runs this again — which is why the server-side layer exists.

## 6. Verify — test the failure path

Installing is not evidence. In the repo you just installed into:

```bash
git commit --allow-empty -m probe              # in the primary: must be REFUSED
git commit --allow-empty --no-verify -m probe  # must be REFUSED once reference-transaction is in
git pull --ff-only                             # must SUCCEED — this is the one people break
git merge --no-ff <any branch>                  # must be REFUSED — needs pre-merge-commit
git commit --amend --no-edit                   # must be REFUSED — pre-commit only
git cherry-pick <any commit>                   # must be REFUSED — reference-transaction only
git revert --no-edit HEAD                      # must be REFUSED — reference-transaction only
git reset --hard HEAD~1                        # must be REFUSED — reference-transaction only
cd <a worktree> && git commit --allow-empty -m probe   # must SUCCEED
```

Line three is the regression that matters: a stricter hook that refuses every update to
`refs/heads/main` passes the first two tests and quietly bricks the primary clone's only job.

## 7. Server-side, the layer that cannot be bypassed

Local hooks are per-machine and per-clone. Branch protection is the only enforcement that survives
a fresh clone or a colleague's laptop:

```bash
gh api -X PUT repos/<owner>/<repo>/branches/main/protection \
  -f 'required_pull_request_reviews[required_approving_review_count]=0' \
  -F 'enforce_admins=true' -F 'required_status_checks=null' -F 'restrictions=null'
```

**Confirm before running it.** It changes the repo for everyone with access, and `enforce_admins`
locks the owner out of their own direct pushes — the point, but their call to make.

## Limits — say these out loud when you install

- `-c core.hooksPath=/dev/null` bypasses all of it. Guardrail, not a boundary.
- Hooks are not cloned; every machine needs the install run again.
- No hook can stop a branch *switch*. `post-checkout` only notices after the fact, and guarding
  `HEAD` in `reference-transaction` also refuses `git worktree add -b` — the two are
  indistinguishable there. Drift off `main` is warned about, never prevented.
- `git commit --amend` fires no ref transaction at all, so `reference-transaction` is blind to it.
  That is why the `pre-commit` family stays even after installing the stronger hook.
- Prior art in this setup: `erlia/ja-changelog/.githooks/` — the `pre-commit` / `post-checkout`
  pair, with the incident that motivated it recorded in the hook's own comments. Read it first. It
  predates the `cherry-pick` / `revert` finding and does not cover those.
