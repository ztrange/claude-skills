# Guardrail evidence — measurements, and why the hooks are written this way

Read this before **changing** a hook body or the allowlist. Installing does not need it.

## `GIT_REFLOG_ACTION` at the ref transaction (git 2.55.0)

| Command | Value |
|---|---|
| `commit`, `cherry-pick`, `revert`, `reset --hard` | **unset** |
| `merge --no-ff` / `--ff-only` | `merge <ref>` |
| `pull --ff-only` | `pull --ff-only` |

The destructive paths are refused by *falling through* to the default, not by failing a match. So
the test must stay an allowlist, never a presence check like
`[ -n "$GIT_REFLOG_ACTION" ] && continue`: the two behave identically on this version, but the
presence check inverts the default — it permits anything git chooses to label, now or in a future
version, and fails by silent permission rather than noisy refusal.

## `old = new` un-breaks `git stash`

`git stash push` finishes by resetting the worktree to `HEAD`, a no-op transaction on
`refs/heads/main`. v3 had no guard. Measured with real work in the tree:

| | v3 | v4 |
|---|---|---|
| `git stash push` exit code | **1** | 0 |
| stash entry created / worktree cleaned | yes / yes | yes / yes |
| message | `refused: 'commit' would move main` | — |
| the retry a user then makes | `No local changes to save`, **exit 0** | n/a |

The worst shape a bug can take: the stash *worked*, the user was told it failed, and the obvious
retry reports success while their changes sit in `stash@{0}`. It also hit the recovery route for the
most common refusal there is — someone whose `git commit` was refused reaching for `git stash`.

The same line permits `git reset --hard HEAD` and un-breaks `merge --abort` / `cherry-pick --abort`,
which also finish by resetting to `HEAD`. Under v3 the guardrail refused its own teardown and left
the primary wedged mid-merge with nothing but the `core.hooksPath` bypass on offer.

## Recovery after a refusal, measured on v4

| after a refused… | `--abort` | leaves |
|---|---|---|
| `merge --no-ff` | exit 0, tree clean | `MERGE_HEAD`, `MERGE_MSG` |
| `cherry-pick` | exit 0, tree clean | `CHERRY_PICK_HEAD` |
| `merge --squash` + commit | **exit 128** — no `MERGE_HEAD` to abort | `SQUASH_MSG` |
| `revert` | **exit 128** — nothing in progress | nothing but a dirty tree |

`git reset --hard HEAD` is the universal fallback: it clears the tree, `MERGE_HEAD`, `MERGE_MSG` and
`SQUASH_MSG` in every row. Hence `git merge --abort || git reset --hard HEAD` in the hook message —
correct in both merge shapes, copy-pasteable as written.

Also measured: with all four hooks installed and an uncommitted edit in the primary,
`git reset --hard HEAD~1` was refused and `main` never moved — and the uncommitted edit was gone,
with the index left matching `HEAD~1` against an unmoved `HEAD`. A failed `pull --ff-only` behaves
the same, leaving fetched content staged.

## Why the messages are conditional

A refused plain `git commit` must **not** print the reset advice: there the dirty tree is the user's
own work, and `reset --hard HEAD` deletes exactly what they were trying to commit. The
`reference-transaction` body cannot always tell those apart — `commit --no-verify` and `reset --hard`
both reach it with `GIT_REFLOG_ACTION` unset and no state file between them — so there the safety is
carried by labelling the command `DISCARDS uncommitted changes` and prefixing it with `git status`,
true in every case it can print in.

v3 refusals handed the reader exactly one escape, `core.hooksPath=/dev/null` — the bypass the
guardrail exists to discourage — while the way out it actually wanted was three sections away.

## Why `${0##*/}` and not `MERGE_HEAD`

Git writes `MERGE_HEAD` *after* the hook refuses, so the commit can be resumed. Measured on a
diverged probe: `pre-merge-commit` sees no `MERGE_HEAD`, `MERGE_MSG` or `SQUASH_MSG`, and the file
appears only once the refusal has landed. Inside the hook the only thing distinguishing a merge from
an ordinary commit is which name the body was invoked under. The `SQUASH_MSG` test beside it covers
`merge --squash`, which reaches `pre-commit` with the squashed content already staged.

`$op` exists for the same reason: one body under two names would otherwise tell someone whose
`git merge` was refused that the escape is `core.hooksPath=/dev/null commit`, a bypass that does not
bypass what they ran. `--squash` keeps `op=commit`, because there the user really did type
`git commit`.

## Version history

| | Changed | Replace because |
|---|---|---|
| v2 → v3 | all four bodies | v2's `pre-commit` says `--no-verify` bypasses it, which the `reference-transaction` hook makes false. Misleading beats stale |
| v3 → v4 | all four bodies; `reference-transaction` gained `[ "$old" = "$new" ] && continue` | **Behavioural** — un-breaks `git stash` and `--abort`. Messages gained the conditional recovery lines |
| v4 → v5 | messages only — `post-checkout` gained the remedy | Deferrable; a v4 install is less useful when it fires, not broken |

A message-only change bumps at all because **the version number is the only channel there is.**
Hooks are copied into each repo, not linked; nothing phones home. A skill edit that leaves the
marker alone reaches no installed repo ever — the classifier reads v4 in the file, v4 in the skill,
prints `current -> leave`, and the old message stays forever. The cost is that the marker lives in
all four bodies, so one message change makes all four files differ and a re-run rewrites all four.
They are managed files by definition, so that is noise rather than risk — but it is why the bar for
bumping is "the change must actually reach someone".

## `session-drift-check.sh` — three load-bearing details

- **The default branch comes from `origin/HEAD`, not the literal `main`.** Across 19 local repos one
  parks on `Dev`; hardcoding `main` warns every session about a correctly-parked clone, which is how
  a guardrail becomes something you learn to skip. `git clone` sets `origin/HEAD`, so the `main`
  fallback is only for a repo that lost it.
- **A detached HEAD is drift and must be named.** `symbolic-ref` *fails* there rather than returning
  something, so the obvious form leaves the branch variable empty and reports nothing — and
  `git switch --detach main` is one of the two paths the guardrail exists for.
- **It must exit 0 on the happy path.** The natural one-liner — `[ test ] && echo …` — ends on a
  false test when the primary *is* parked correctly, so the hook exits 1 every session forever.
  Structure it so `exit 0` is the last statement.

Verified from all three vantage points — inside the primary, inside a subdirectory, from a linked
worktree — plus outside any repo, where `dirname` of a failed `rev-parse` would resolve to `/`.

## What `scripts/test-guardrail.sh` asserts, and how it was checked

It asserts message *content*, not just exit codes, via `refused_saying`, `warned` and `drift_says`.
The negative direction is the one that matters: a refused plain `git commit` must not mention
`reset --hard`, and the drift check must say *nothing at all* when the primary is parked correctly.

Both directions are mutation-tested — making the merge advice unconditional fails `git commit`,
dropping the `CHERRY_PICK_HEAD` test fails `git revert`, hardcoding `main` in place of `origin/HEAD`
fails all three `Dev` assertions, dropping the detached-HEAD fallback fails that one, and rewriting
the drift check as `[ test ] && echo …` fails every *silent* assertion at once because it then exits
1 on the happy path.

**The path in the drift report is asserted by property, not by string.** The same primary resolves to
`/var/folders/…` from inside itself and `/private/var/folders/…` from a linked worktree — git records
the real path in the worktree's `.git` file and macOS symlinks `/var`. Both are valid and `git -C`
accepts either, so the assertion extracts the path from the `Fix:` line and checks that `--git-dir`
and `--git-common-dir` agree there.

One trap the suite had to learn: **a refused merge or cherry-pick leaves the tree dirty, and git then
refuses the next probe by itself** — `local changes would be overwritten by cherry-pick`, before any
hook runs. That exits non-zero with `main` unmoved, so an exit-code-only assertion passes while
testing nothing. The suite tears down to a clean tree between probes and fails loudly if it can't.

## Branch protection: why every flag is `-F`

`-f` is `--raw-field`, which sends the value as a JSON *string*; `required_approving_review_count`
must be a typed integer, so `-f` on that field fails with
`422: For 'properties/required_approving_review_count', "0" is not an integer`. `-F` is `--field`,
which infers the type, and does so correctly through the `a[b]` bracket syntax — verified on `gh`
2.96.0. No heredoc or `--input -` needed.

`gh api` exits non-zero on a 4xx — measured, exit 1 on a 404 — so a bare call fails loudly. What
hides it is a pipe: `gh api … | tail -1` reports `tail`'s status, which is 0 whatever the API said.
Same trap as `${PIPESTATUS[0]}`, which is a bashism that silently expands to nothing under zsh, the
macOS default. Test `$?` directly without a pipe, or spell it `${pipestatus[1]}`.
