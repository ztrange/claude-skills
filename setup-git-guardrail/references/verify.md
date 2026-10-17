# Verifying a fresh install

`scripts/test-guardrail.sh` covers development against a throwaway lab. This is the manual check for
a repo you just installed into. Three things make it work rather than theatre:

- **The pass criterion is the sha, not the error message.** "Refused" and "`main` didn't move" are
  different claims and only the second is the invariant — a refusal is never a no-op, since git
  writes the index and worktree before the ref transaction aborts.
- **The primary must be clean before you start** — these probes destroy uncommitted work in it.
- **The probes need a ref ahead of `main`**, and creating one in the primary is circular. Build it in
  a worktree, which doubles as two of the tests.

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

## `pull --ff-only` is the regression that matters, and the obvious test for it is vacuous

A hook that refuses *every* update to `refs/heads/main` passes every probe above and quietly bricks
the primary's only job. Running `git pull --ff-only` in a primary that is already current does not
catch it: **no ref transaction fires, so the hook is never consulted.** Measured with an
allowlist-free hook deliberately installed: an up-to-date primary reported `Already up to date` and
exit 0 — passing — while the same hook on a primary genuinely behind refused the fast-forward and
pinned `main` in place.

Being current is the *normal* state of a clone whose job is sitting on `main`, so create the
condition. Use a throwaway clone, since the alternatives require moving `origin/main`:

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
