---
name: install-guardrails
description: >-
  Install git hooks that keep the primary clone parked on `main` and push all work into worktrees:
  a `pre-commit` that refuses any commit made in the primary clone, and a `post-checkout` that says
  so loudly when the primary drifts off `main`. Use when the user says "install guardrails",
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

Document the `--no-verify` escape in the hook's own error message, as above. A guard whose bypass
is stated is a design choice, not a weakness: it makes the common accident loud without standing
between someone and an unusual but intentional action.

## 4. Why not `reference-transaction` — measured, not assumed

It looks strictly better: the one hook `--no-verify` cannot skip, and unlike `post-checkout` it
appears able to refuse a branch switch outright. It was built and run head-to-head against the
hooks above. **It is worse.** The results, on git 2.50.1:

| Operation | `pre-commit` (shipped) | `reference-transaction` |
|---|---|---|
| commit in the primary clone | refused | refused |
| `commit --no-verify` | allowed — the documented escape | **refused** ← its only win |
| `commit --amend` | refused | **allowed** ← blind spot |
| `reset --hard HEAD~1` | allowed | **refused** ← false refusal |
| `worktree add -b`, `branch`, `pull --ff-only` | allowed | allowed, once the `HEAD` guard is dropped |
| refuse a branch *switch* | no | no — see below |

Three findings decide it, each reproduced:

- **`git commit --amend` fires no ref transaction at all.** A plain commit fires one for
  `refs/heads/main`; amend fires none, in any state. The guard cannot see the operation, so no
  amount of tuning catches it. `pre-commit` does run on amend and refuses it.
- **The switch guard is unusable.** `git switch` and `git worktree add -b` present the hook with
  identical `PWD`, `GIT_DIR`, `rev-parse --git-dir` and environment — there is nothing to
  discriminate on. Guarding `HEAD` therefore refuses the exact command the guardrail exists to
  encourage. Dropping the `HEAD` guard fixes that, and gives up the one capability that made the
  mechanism attractive.
- **It refuses `git reset --hard`**, which leaves `GIT_REFLOG_ACTION` unset exactly like a commit.
  Legitimate local surgery, blocked.

So it trades a documented escape hatch for an undocumented one (`-c core.hooksPath=/dev/null`),
gains resistance to `--no-verify`, and pays with a blind spot and a false refusal. Not a trade
worth making. Recorded here because the idea is genuinely tempting and will come back.

## 5. Where the hooks live

Hooks live in the common git dir, so **one install covers every worktree** of the repo:

```bash
install -m 755 <hook> "$(git rev-parse --git-common-dir)/hooks/pre-commit"
install -m 755 <hook> "$(git rev-parse --git-common-dir)/hooks/pre-merge-commit"
install -m 755 <warn> "$(git rev-parse --git-common-dir)/hooks/post-checkout"
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
git commit --allow-empty --no-verify -m probe  # allowed, by design — the documented escape
git pull --ff-only                             # must SUCCEED — this is the one people break
git merge --no-ff <any branch>                  # must be REFUSED — needs pre-merge-commit
git commit --amend --no-edit                   # must be REFUSED
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
- `pre-commit` cannot stop a branch *switch*; `post-checkout` only notices one after the fact.
  The primary drifting off `main` is warned about, never prevented. See section 4 for why the hook that
  could prevent it was rejected.
- Prior art in this setup: `erlia/ja-changelog/.githooks/` — the same two hooks, with the
  incident that motivated them recorded in the hook's own comments. Read it before writing new ones.
