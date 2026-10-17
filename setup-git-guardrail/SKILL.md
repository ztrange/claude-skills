---
name: setup-git-guardrail
description: >-
  Install git hooks that keep the primary clone parked on `main` and push all work into worktrees: a
  `pre-commit` and `pre-merge-commit` that refuse any commit made in the primary clone, a
  `reference-transaction` hook that catches the paths those never see (`cherry-pick`, `revert`,
  `reset --hard`, `--no-verify`), and a `post-checkout` that says so loudly — and says how to undo
  it — when the primary drifts off `main`. Adds a Claude Code `SessionStart` hook that restates that
  drift in later sessions. Use when the user says "set up git guardrails", "install guardrails",
  "protect main", "prevent commits to main", "stop me committing in the primary clone", "add the git
  hooks", "set up branch protection", "update the git hooks", "the primary is on the wrong branch",
  "detect drift off main", or "instala los guardrails". Checks what git already enforces before
  installing, verifies by testing the failure path — including that `git pull --ff-only` still works
  — and states plainly where the guardrail can be bypassed.
---

# Install guardrails — the primary clone holds `main`, work happens in worktrees

**The invariant is not "no commits on `main`". It is "nothing is committed in the primary clone."**
The primary's one job is to sit on `main` and hold it so every worktree can branch from it. Guard the
clone, not the branch name.

**Detect the primary by structure, never by path.** In the primary, `--git-dir` and
`--git-common-dir` resolve to the same directory; in a linked worktree `--git-dir` is
`<common>/worktrees/<name>`. That makes the hook portable and committable.

**Not a security boundary.** `git -c core.hooksPath=/dev/null commit` skips every hook here. It stops
accidents, not intent.

## 1. What breaks when the invariant breaks

A branch can be checked out in only one worktree at a time, so the moment the primary drifts onto a
feature branch `main` is either claimed by something disposable or unavailable:

- every other worktree's `git checkout main` fails with `'main' is already used by worktree at …`
- `gh pr merge --delete-branch` fails its local step **after the merge has landed** — the exit code
  says failure while the PR says merged, and the local branch survives

The second is the expensive one: it invites a retry of a merge that already happened.

## 2. What git already enforces

If the primary keeps `main` checked out, git refuses to put `main` in a second worktree. Confirm in
the target repo before writing anything:

```bash
git worktree add /tmp/probe main    # fatal: 'main' is already used by worktree at ...
```

What it does *not* cover, and the only reason to install more:

- `git switch --ignore-other-worktrees main` — explicitly opts out
- `git switch --detach main` — takes the commit without claiming the branch
- committing in the primary clone on any branch at all, which git never objects to

## 3. The refusing hooks

`pre-commit`, keyed on the primary-clone test:

```sh
#!/bin/sh
# managed-by: setup-git-guardrail v5 — re-run the skill to update; edits here are overwritten
git_dir=$(cd "$(git rev-parse --git-dir)" && pwd)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$git_dir" = "$common_dir" ] || exit 0     # linked worktree: this is where work belongs
case "${0##*/}" in pre-merge-commit) op=merge ;; *) op=commit ;; esac   # name the right bypass
echo "  refused: this is the primary clone; it exists to sit on main and hold it." >&2
echo "    git worktree add .claude/worktrees/<task> -b claude/<task> origin/main" >&2
echo "    to update the primary, never merge:  git pull --ff-only" >&2
if [ "$op" = merge ] || [ -e "$git_dir/SQUASH_MSG" ]; then
  echo "    the merge is half-applied; undo it before anything else:" >&2
  echo "    git merge --abort || git reset --hard HEAD   # the fallback DISCARDS uncommitted work" >&2
fi
echo "    --no-verify does NOT bypass this; the escape is:" >&2
echo "    git -c core.hooksPath=/dev/null $op ..." >&2
exit 1
```

**The merge branch keys on `${0##*/}`, not `MERGE_HEAD`, because `MERGE_HEAD` does not exist yet.**
Git writes it *after* the hook refuses, so the commit can be resumed — measured on a diverged probe,
`pre-merge-commit` sees no `MERGE_HEAD`, `MERGE_MSG` or `SQUASH_MSG`. Inside the hook the only thing
distinguishing a merge from an ordinary commit is which name the body was invoked under, and `$0`
carries that. The `SQUASH_MSG` test beside it covers `merge --squash`, which reaches `pre-commit` with
the squashed content already staged.

`$op` exists for the same reason: one body under two names would otherwise tell someone whose
`git merge` was refused that the escape is `core.hooksPath=/dev/null commit`, a bypass that does not
bypass what they ran. `--squash` keeps `op=commit`, because there the user really did type
`git commit`.

**That message is written for the all-four install of section 4, the recommended one.** Installing
only this family → `--no-verify` *does* bypass, and the last two lines must say so instead:
`if you truly meant this, git commit --no-verify bypasses it.` Ship whichever is true of the install
you performed. A hook that misstates its own bypass is worse than one with no bypass line: it is read
exactly once, by someone deciding what to do next.

`post-checkout` warns when the primary leaves `main` and **must exit 0** — exiting non-zero reports an
error about a switch that already succeeded, which lies in the one place someone is reading. Args:
`$1` old HEAD, `$2` new HEAD, `$3` = 1 for a branch switch.

```sh
#!/bin/sh
# managed-by: setup-git-guardrail v5 — re-run the skill to update; edits here are overwritten
[ "$3" = "1" ] || exit 0
git_dir=$(cd "$(git rev-parse --git-dir)" && pwd)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$git_dir" = "$common_dir" ] || exit 0
branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = main ] && exit 0
echo "  ⚠ primary clone is on '$branch', not main — no worktree can check out main while it is" >&2
echo "    git switch main                # then branch in a worktree instead:" >&2
echo "    git worktree add .claude/worktrees/<task> -b claude/<task> origin/main" >&2
exit 0
```

**This is the only hook here that warns rather than refuses, so its message carries the whole fix.** A
refusal leaves the user where they were and can afford to be terse; a warning arrives *after* the
state it describes is true. `git switch main` is the entire remedy, and it is permitted by the
`reference-transaction` hook (a `HEAD` update is not a `refs/heads/*` transaction).

`pre-commit` does not run for merge commits — git calls `pre-merge-commit` — so `git merge --no-ff`
lands on `main` untouched without it. **Install the same body under both names.** A squash merge is
caught by `pre-commit`, since it ends in an ordinary commit.

On its own this family is bypassed by `--no-verify`. Documenting that in the message makes the common
accident loud without standing between someone and a deliberate act — defensible, and the reason the
section-3-only variant exists. Decide which behaviour is wanted before installing: the choice changes
the hook body, not just which files get written.

## 4. The second mechanism — neither one is enough alone

`pre-commit` never runs for `cherry-pick`, `revert` or `reset --hard`, so all three land on `main` in
the primary untouched. Measured: `main` went from 1 commit to 3 with the section-3 hooks installed. A
`reference-transaction` hook catches exactly those, because they are ref updates:

```sh
#!/bin/sh
# managed-by: setup-git-guardrail v5 — re-run the skill to update; edits here are overwritten
[ "$1" = prepared ] || exit 0
gd=$(cd "$(git rev-parse --git-dir)" && pwd); cm=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$gd" = "$cm" ] || exit 0
while read -r old new ref; do
  case "$ref" in refs/heads/*) ;; *) continue ;; esac
  [ "$old" = 0000000000000000000000000000000000000000 ] && continue   # branch creation, and worktree add -b
  [ "$old" = "$new" ] && continue   # ref does not move: cannot touch the graph. git stash, reset --hard HEAD
  case "${GIT_REFLOG_ACTION-}" in pull*|merge*|fetch*) continue ;; esac  # remote sync, allowlisted
  echo "  refused: '${GIT_REFLOG_ACTION:-commit}' would move ${ref#refs/heads/} in the primary clone" >&2
  echo "    work belongs in a worktree; the primary sits on main and holds it:" >&2
  echo "    git worktree add .claude/worktrees/<task> -b claude/<task> origin/main" >&2
  [ -e "$gd/CHERRY_PICK_HEAD" ] && echo "    still mid-cherry-pick; undo it with:  git cherry-pick --abort" >&2
  echo "    a refusal is not a no-op — the index and worktree may already be written:" >&2
  echo "    git status, then  git reset --hard HEAD   # DISCARDS uncommitted changes" >&2
  echo "    --no-verify does NOT bypass this; the escape is:" >&2
  echo "    git -c core.hooksPath=/dev/null <cmd> ..." >&2
  exit 1
done
exit 0
```

**The allowlist is load-bearing, and it must stay an allowlist.** Only `pull`, `merge` and `fetch` may
move a branch here; everything else, *including an unset action*, is refused. Measured on git 2.55.0:

| Command | `GIT_REFLOG_ACTION` at the ref transaction |
|---|---|
| `commit`, `cherry-pick`, `revert`, `reset --hard` | **unset** |
| `merge --no-ff` / `--ff-only` | `merge <ref>` |
| `pull --ff-only` | `pull --ff-only` |

So the destructive paths are refused by *falling through* to the default, not by failing a match. That
is why this must not be a presence check like `[ -n "$GIT_REFLOG_ACTION" ] && continue`: the two behave
identically on this version, but the presence check inverts the default — it permits anything git
chooses to label, now or in a future version, and fails by silent permission rather than noisy
refusal. Default to refusing; enumerate the exceptions.

### `old = new` is a guard, not an allowlist entry — and skipping it breaks `git stash`

`[ "$old" = "$new" ]` is the invariant restated: **a transaction where the ref does not move cannot
change the commit graph**, so refusing it protects nothing. Unlike the allowlist it cannot be widened
by a future git relabelling something — it is a property of the transaction.

Leaving it out is what v3 did, and it broke `git stash` in the primary. `git stash push` finishes by
resetting the worktree to `HEAD`, which opens a no-op transaction on `refs/heads/main`. Measured with
real work in the tree:

| | v3 | v4 |
|---|---|---|
| `git stash push` exit code | **1** | 0 |
| stash entry created / worktree cleaned | yes / yes | yes / yes |
| message | `refused: 'commit' would move main` | — |
| the retry a user then makes | `No local changes to save`, **exit 0** | n/a |

The worst shape a bug can take: the stash *worked*, the user was told it failed, and the obvious retry
reports success while their changes sit in `stash@{0}`. It also hit the recovery route for the most
common refusal there is — someone whose `git commit` was just refused reaching for `git stash`.

The same line permits `git reset --hard HEAD`, so recovery advice can be a command people already
know, and it un-breaks `git merge --abort` / `git cherry-pick --abort`, which also finish by resetting
to `HEAD`. Under v3 the guardrail refused its own teardown and left the primary wedged mid-merge with
nothing but the `core.hooksPath` bypass on offer.

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
| `git stash push` / `git reset --hard HEAD` | allowed | allowed — `old = new`, v4 |
| `pull --ff-only`, `worktree add -b`, commit in a worktree | allowed | allowed |

**Install all four hooks**, each carrying the `managed-by` marker. Verified together: every refusal
above holds and all three permitted operations work.

### "Refused" means the ref did not move. It does not mean nothing happened

**Git writes the index and working tree first, then opens the ref transaction the hook aborts.** Every
"refused" above is a claim about the commit graph only. Measured with all four hooks installed and an
uncommitted edit in the primary: `git reset --hard HEAD~1` was refused, `main` never moved — and the
uncommitted edit was gone, with the index left matching `HEAD~1` against an unmoved `HEAD`. A failed
`pull --ff-only` behaves the same, leaving fetched content staged.

State the guarantee as **the commit graph is protected**, never as *the command is a no-op*. Recovery
is `git reset --hard HEAD` (v4+), or `git restore --source=HEAD --staged --worktree .`, which touches
no refs and so works under v3 too — prefer it in advice aimed at an install you have not verified.

A refused `merge --no-ff` or `cherry-pick` also leaves `MERGE_HEAD` / `CHERRY_PICK_HEAD` behind, with
the primary mid-operation. Measured on v4:

| after a refused… | `--abort` | leaves |
|---|---|---|
| `merge --no-ff` | exit 0, tree clean | `MERGE_HEAD`, `MERGE_MSG` |
| `cherry-pick` | exit 0, tree clean | `CHERRY_PICK_HEAD` |
| `merge --squash` + commit | **exit 128** — no `MERGE_HEAD` to abort | `SQUASH_MSG` |
| `revert` | **exit 128** — nothing in progress | nothing but a dirty tree |

So `--abort` is the recovery where one exists, and `git reset --hard HEAD` is the universal fallback:
measured, it clears the tree, `MERGE_HEAD`, `MERGE_MSG` and `SQUASH_MSG` in every row. That is why the
merge message spells it `git merge --abort || git reset --hard HEAD` — correct in both merge shapes,
copy-pasteable as written.

**The hook bodies say all of this themselves, conditionally, and the conditions matter as much as the
lines.** A refused plain `git commit` must **not** print the reset advice: there the dirty tree is the
user's own work, and `reset --hard HEAD` deletes exactly what they were trying to commit. The
`reference-transaction` body cannot always tell those apart — `commit --no-verify` and `reset --hard`
both reach it with `GIT_REFLOG_ACTION` unset and no state file between them — so there the safety is
carried by labelling the command `DISCARDS uncommitted changes` and prefixing it with `git status`,
true in every case it can print in.

Two costs, both worth saying when installing:

- **`--no-verify` no longer bypasses.** The escape becomes `git -c core.hooksPath=/dev/null …`, which
  is not discoverable from the error message, so it goes *in* the message — and in the section 3 body
  too, which otherwise ships advice this hook makes false.
- **A branch *switch* still cannot be blocked.** Guarding `HEAD` here would refuse `git worktree add
  -b` as well: that command and `git switch` present identical `PWD`, `GIT_DIR`, `rev-parse --git-dir`
  and environment, so there is nothing to discriminate on. `post-checkout` after the fact is the only
  option.

## 5. Where the hooks live

Hooks live in the common git dir, so **one install covers every worktree**.

**Resolve that path with `cd … && pwd`, never by string-pasting.** `git rev-parse --git-common-dir`
returns a path *relative to the current directory* inside the primary — `.git` at the top level,
`../.git` one directory down — and absolute only from a linked worktree. Pasting the relative form
into an `install` target writes the hooks wherever your shell happens to be standing.

```bash
H="$(cd "$(git rev-parse --git-common-dir)" && pwd)/hooks"
install -m 755 <refuse>  "$H/pre-commit"
install -m 755 <refuse>  "$H/pre-merge-commit"
install -m 755 <reftxn>  "$H/reference-transaction"
install -m 755 <warn>    "$H/post-checkout"
```

To version the hooks instead, keep a tracked `.githooks/` and point git at it — but know the
trade-off: **a relative `core.hooksPath` resolves against each worktree's own top level**, so the
hooks vanish on any branch that doesn't carry the directory. Usually harmless (the primary sits on
`main`, which has it) and occasionally baffling. An absolute path fires everywhere and is not
committable.

```bash
git config core.hooksPath .githooks     # tracked, shared, per-branch, per-clone
```

Either way `core.hooksPath` is **not carried by a clone** — a fresh clone has no hooks until someone
runs this again, which is why the server-side layer exists.

## 6. Upgrading an existing install

Most repos that want this already have *something*, usually an older `pre-commit` predating the
`cherry-pick` / `revert` findings. **Re-running must be safe on those.** Every hook this skill writes
carries a marker as its second line, and that marker is the whole upgrade mechanism:

```sh
# managed-by: setup-git-guardrail v5 — re-run the skill to update; edits here are overwritten
```

Classify all four names before writing anything:

```bash
if H=$(git config --get core.hooksPath) && [ -n "$H" ]; then
  case "$H" in /*) ;; *) H="$(git rev-parse --show-toplevel)/$H" ;; esac  # relative: per-worktree
else
  H="$(cd "$(git rev-parse --git-common-dir)" && pwd)/hooks"              # never string-paste this
fi
echo "hooks dir: $H"
for h in pre-commit pre-merge-commit reference-transaction post-checkout; do
  if   [ ! -e "$H/$h" ];                              then echo "$h: absent      -> install"
  elif v=$(sed -n 's/^# managed-by: setup-git-guardrail v\([0-9]*\).*/\1/p' "$H/$h") && [ -n "$v" ]; then
       [ "$v" = 5 ] && echo "$h: v$v current -> leave" || echo "$h: v$v outdated -> replace"
  else echo "$h: UNMANAGED  -> do not touch; report it"
  fi
done
```

**Print `$H` and check it before trusting the classification.** The two branches are not
interchangeable: because `--git-common-dir` is relative inside the primary, the older form
(`H=${H:-$(git rev-parse --git-common-dir)/hooks}` rewritten against `--show-toplevel`) resolves to
`<toplevel>/../.git/hooks` when run one directory down. That directory does not exist, so every hook
classifies as **absent**, a fully-guarded repo reads as unguarded, and the install writes four hooks
outside the repo where nothing runs them. Silent in both directions. **An `absent` verdict on a repo
you believe is installed means the path is wrong, not the hooks.**

| State | Action |
|---|---|
| absent | Install it |
| marker, older version | Replace in place |
| marker, current version | Leave alone — re-running is a no-op |
| **no marker** | **Never overwrite.** Someone wrote it by hand |

What each bump changed, since an older install is a real thing to meet:

| | Changed | Replace because |
|---|---|---|
| v2 → v3 | all four bodies | v2's `pre-commit` says `--no-verify` bypasses it, which the `reference-transaction` hook makes false. Misleading beats stale |
| v3 → v4 | all four bodies; `reference-transaction` gained `[ "$old" = "$new" ] && continue` | **Behavioural** — un-breaks `git stash` and `--abort` in the primary. Messages also gained the conditional recovery lines |
| v4 → v5 | messages only — `post-checkout` gained the remedy | Deferrable without consequence; a v4 install is less useful in the moment it fires, not broken |

A message-only change bumps at all because **the version number is the only channel there is.** Hooks
are copied into each repo, not linked; nothing phones home. A skill edit that leaves the marker alone
reaches no installed repo ever — the classifier reads v4 in the file, v4 in the skill, prints
`current -> leave`, and the old message stays forever. The cost is that the marker lives in all four
bodies, so one message change makes all four files differ and a re-run rewrites all four. They are
managed files by definition, so that is noise rather than risk — but it is why the bar for bumping is
"the change must actually reach someone".

An unmanaged hook is the `ja-changelog` case: a hand-written `pre-commit` carrying the incident that
motivated it in its own comments. That commentary is worth more than the code. Copy it to
`<hook>.pre-guardrail.bak`, show the user the diff against what the skill would install, and let them
choose. **Do not merge the two automatically.**

The common real-world result is a partial upgrade: two unmanaged hooks left in place and the two
missing files (`pre-merge-commit`, `reference-transaction`) added alongside, which closes the
`cherry-pick` / `revert` / `merge --no-ff` holes without touching anything hand-written. Say which
files you added and which you left, by name.

## 7. Verify — test the failure path

**Changing anything in this skill? Run `scripts/test-guardrail.sh` first.** It builds a throwaway
upstream + primary + worktree under `mktemp -d`, installs the four hook bodies *extracted from this
file* — so the suite cannot drift from the hooks it documents — and asserts every row of the section 4
tables, the `pull --ff-only` allowlist, the `git stash` round-trip, the `post-checkout` warning and its
remedy, the section 9 drift check from all four vantage points, and the hooks-path resolution. It
touches no real repository. 50 assertions, exit 0 when they all hold.

**It asserts message *content*, not just exit codes**, via `refused_saying`, `warned` and `drift_says`.
The negative direction is the one that matters: a refused plain `git commit` must not mention
`reset --hard`, and the drift check must say *nothing at all* when the primary is parked correctly.
Both directions are mutation-tested — making the merge advice unconditional fails `git commit`,
dropping the `CHERRY_PICK_HEAD` test fails `git revert`, hardcoding `main` in place of `origin/HEAD`
fails all three `Dev` assertions, dropping the detached-HEAD fallback fails that one, and rewriting the
drift check as `[ test ] && echo …` fails every *silent* assertion at once because it then exits 1 on
the happy path.

**The path in the drift report is asserted by property, not by string.** The same primary resolves to
`/var/folders/…` from inside itself and `/private/var/folders/…` from a linked worktree — git records
the real path in the worktree's `.git` file and macOS symlinks `/var`. Both are valid and `git -C`
accepts either, so the assertion extracts the path from the `Fix:` line and checks that `--git-dir` and
`--git-common-dir` agree there.

One trap the suite had to learn: **a refused merge or cherry-pick leaves the tree dirty, and git then
refuses the next probe by itself** — `local changes would be overwritten by cherry-pick`, before any
hook runs. That exits non-zero with `main` unmoved, so an exit-code-only assertion passes while testing
nothing. The suite tears down to a clean tree between probes and fails loudly if it can't.

That covers development. For a repo you just installed into, three things make the manual check real:

- **The pass criterion is the sha, not the error message.** "Refused" and "`main` didn't move" are
  different claims and only the second is the invariant. Record `git rev-parse main` before and after.
- **The primary must be clean before you start** — these probes destroy uncommitted work in it.
- **The probes need a ref ahead of `main`**, and creating one in the primary is circular. Build it in a
  worktree, which doubles as two of the tests.

```bash
cd <primary>
[ -z "$(git status --porcelain)" ] || { echo "primary is dirty — stop"; exit 1; }
BEFORE=$(git rev-parse main)

git worktree add /tmp/gr-probe -b probe/guardrail main   # must SUCCEED — old=0000 allowlist
git -C /tmp/gr-probe commit --allow-empty -m probe       # must SUCCEED — work belongs here
PROBE=$(git -C /tmp/gr-probe rev-parse HEAD)

echo scratch > gr-stash.txt && git add gr-stash.txt
git stash push -m gr-probe                       # must SUCCEED and exit 0 — v4's old=new guard
git stash pop && git rm -qf --cached gr-stash.txt && rm -f gr-stash.txt

git commit --allow-empty -m probe                # must be REFUSED
git commit --allow-empty --no-verify -m probe    # must be REFUSED — needs reference-transaction
git commit --amend --no-edit                     # must be REFUSED — pre-commit only
git merge --no-ff probe/guardrail                # must be REFUSED — needs pre-merge-commit
git merge --abort                                # teardown: ALLOWED from v4; must leave a clean tree
git cherry-pick "$PROBE"                         # must be REFUSED — reference-transaction only
git cherry-pick --abort                          # teardown: ALLOWED from v4; must leave a clean tree
git revert --no-edit HEAD                        # must be REFUSED — reference-transaction only
git reset --hard HEAD                            # teardown: revert leaves no REVERT_HEAD to abort
git reset --hard HEAD~1                          # must be REFUSED — DESTROYS the working tree

git reset --hard HEAD                            # teardown: ALLOWED from v4 (old = new)
git worktree remove --force /tmp/gr-probe && git branch -D probe/guardrail

[ "$(git rev-parse main)" = "$BEFORE" ] && [ -z "$(git status --porcelain)" ] \
  && echo "PASS: main unmoved at $BEFORE, tree clean" || echo "FAIL"
```

Avoid `${PIPESTATUS[0]}` if you capture exit codes here — a bashism that silently expands to nothing
under zsh, the macOS default. Test `$?` directly without a pipe, or spell it `${pipestatus[1]}`.

### `pull --ff-only` is the regression that matters, and the obvious test for it is vacuous

A hook that refuses *every* update to `refs/heads/main` passes every check above and quietly bricks the
primary's only job. Running `git pull --ff-only` in a primary that is already current does not catch
it: **no ref transaction fires, so the hook is never consulted.** Measured with an allowlist-free hook
deliberately installed: up-to-date primary reported `Already up to date` and exit 0 — passing — while
the same hook on a primary genuinely behind refused the fast-forward and pinned `main` in place.

Being current is the *normal* state of a clone whose job is sitting on `main`, so create the condition.
Do it in a throwaway clone, since the alternatives require moving `origin/main`:

```bash
git clone <primary> /tmp/gr-pull && cd /tmp/gr-pull
# install the same four hooks here, then roll back with the documented bypass:
git -c core.hooksPath=/dev/null reset --hard HEAD~2
BEHIND=$(git rev-parse main)
git pull --ff-only                               # must SUCCEED
[ "$(git rev-parse main)" != "$BEHIND" ] && echo "PASS: allowlist works, main advanced" || echo "FAIL"
cd - && rm -rf /tmp/gr-pull
```

Assert the sha advanced. `git pull` exiting 0 is not the claim — `Already up to date` exits 0 too.

## 8. Server-side, the layer that cannot be bypassed

Local hooks are per-machine and per-clone. Branch protection is the only enforcement that survives a
fresh clone or a colleague's laptop.

```bash
gh api -X PUT repos/<owner>/<repo>/branches/main/protection \
  -F 'required_pull_request_reviews[required_approving_review_count]=0' \
  -F 'enforce_admins=true' -F 'required_status_checks=null' -F 'restrictions=null'
```

**Every flag is `-F`, and that is load-bearing.** `-f` is `--raw-field`, which sends the value as a
JSON *string*; `required_approving_review_count` must be a typed integer, so `-f` on that field fails
with `422: For 'properties/required_approving_review_count', "0" is not an integer`. `-F` is
`--field`, which infers the type, and does so correctly through the `a[b]` bracket syntax — verified
on `gh` 2.96.0. No heredoc or `--input -` needed.

**Confirm before running it.** It changes the repo for everyone with access, and `enforce_admins` locks
the owner out of their own direct pushes — the point, but their call.

**Then read the protection back**, because a request that never applied still prints nothing alarming
if its output was piped:

```bash
gh api repos/<owner>/<repo>/branches/main/protection \
  --jq '{admins: .enforce_admins.enabled, reviews: .required_pull_request_reviews.required_approving_review_count}'
```

`gh api` does exit non-zero on a 4xx — measured, exit 1 on a 404 — so a bare call fails loudly. What
hides it is a pipe: `gh api … | tail -1` reports `tail`'s status, which is 0 whatever the API said.
Same trap as `${PIPESTATUS[0]}` in section 7, one layer up.

## 9. Drift is announced once, into a terminal nobody re-reads

`post-checkout` fires the instant the primary leaves `main` and prints the remedy. Right moment, wrong
durability: it goes to whoever ran `git switch`, scrolls away, and is never restated — while the
expensive consequence from section 1 arrives hours later, in a different session, with nothing on
screen connecting the two. Nothing in git closes this; the check has to run at the *start of a
session*, which puts it outside git's hook set.

[`scripts/session-drift-check.sh`](scripts/session-drift-check.sh) is that check, wired as a Claude
Code `SessionStart` hook in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command",
                     "command": "$HOME/.claude/skills/setup-git-guardrail/scripts/session-drift-check.sh" } ] }
    ]
  }
}
```

**`SessionStart` is one of only three events whose stdout is added to the agent's context** — with
`UserPromptSubmit` and `UserPromptExpansion`; for every other event stdout goes to the debug log. That
is why this is a `SessionStart` hook and not a `PreToolUse` one: the finding has to be read by the
agent about to do the work, not printed at a user who already knows. It cannot block a session, and a
non-zero exit only shows stderr, so a broken script degrades to silence.

Omit the `matcher` so it fires on all of `startup`, `resume`, `clear`, `compact` and `fork` — the
three rebuild-the-context cases are exactly when the fact needs restating.

Three things in the script body are load-bearing, all measured:

- **The default branch comes from `origin/HEAD`, not the literal `main`.** Across 19 local repos one
  parks on `Dev`; hardcoding `main` warns every session about a correctly-parked clone, which is how a
  guardrail becomes something you learn to skip. `git clone` sets `origin/HEAD`, so the `main` fallback
  is only for a repo that lost it.
- **A detached HEAD is drift and must be named.** `symbolic-ref` *fails* there rather than returning
  something, so the obvious form leaves the branch variable empty and reports nothing — and
  `git switch --detach main` is one of the two paths section 2 exists for.
- **It must exit 0 on the happy path.** The natural one-liner — `[ test ] && echo …` — ends on a false
  test when the primary *is* parked correctly, so the hook exits 1 every session forever. Structure it
  so `exit 0` is the last statement.

Verified from all three vantage points — inside the primary, inside a subdirectory, from a linked
worktree — plus outside any repo, where `dirname` of a failed `rev-parse` would resolve to `/`.

This reports; it never refuses. With `post-checkout` the drift is stated twice — once when it happens,
once when it next matters — and prevented neither time.

## Limits — say these out loud when you install

- `-c core.hooksPath=/dev/null` bypasses all of it. Guardrail, not a boundary.
- **The commit graph is protected, not the working tree.** A refused command has already written the
  index and worktree by the time the transaction aborts, so `reset --hard` in the primary still
  destroys uncommitted work. Recover with `git reset --hard HEAD` (v4+) or
  `git restore --source=HEAD --staged --worktree .` (any version) — check `git status` first.
- A refused `merge` or `cherry-pick` leaves the primary mid-operation. From v4 `--abort` clears it;
  under v3 `--abort` was itself refused and the primary stayed wedged.
- Hooks are not cloned; every machine needs the install run again.
- No hook can stop a branch *switch*. Drift off `main` is warned about, never prevented: from v5 the
  warning carries the fix and section 9 restates it in later sessions, but neither is enforcement, and
  the primary can sit drifted indefinitely if both are ignored.
- `git commit --amend` fires no ref transaction, so `reference-transaction` is blind to it. That is why
  the `pre-commit` family stays even after installing the stronger hook.
- Prior art here: `erlia/ja-changelog/.githooks/` — the `pre-commit` / `post-checkout` pair, with the
  incident that motivated it in the hook's own comments. Read it first; it predates the `cherry-pick` /
  `revert` finding and does not cover those.
