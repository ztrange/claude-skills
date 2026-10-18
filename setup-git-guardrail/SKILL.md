---
name: setup-git-guardrail
description: >-
  Install git hooks that keep the primary clone parked on `main` and push all work into worktrees
  — refusing commits made in the primary, catching the paths `pre-commit` never sees
  (`cherry-pick`, `revert`, `reset --hard`, `--no-verify`), and warning when the primary drifts
  off `main` — plus a Claude Code `SessionStart` hook that restates that drift in later sessions.
  Use when the user says "set up git guardrails", "install guardrails", "protect main", "prevent
  commits to main", "stop me committing in the primary clone", "add the git hooks", "set up branch
  protection", "update the git hooks", "the primary is on the wrong branch", "detect drift off
  main". Checks what git already enforces first, verifies by testing the failure path, and states
  plainly where the guardrail can be bypassed.
---

# Install guardrails — the primary clone holds `main`, work happens in worktrees

**The invariant is not "no commits on `main`". It is "nothing is committed in the primary clone."**
The primary's one job is to sit on `main` and hold it so every worktree can branch from it. Guard the
clone, not the branch name.

**Detect the primary by structure, never by path.** In the primary, `--git-dir` and
`--git-common-dir` resolve to the same directory; in a linked worktree `--git-dir` is
`<common>/worktrees/<name>`. That keeps the hook portable and committable.

**Not a security boundary.** `git -c core.hooksPath=/dev/null commit` skips every hook here.

`references/evidence.md` holds the measurements behind every choice below — read it before changing
a hook body or the allowlist, not to install. `references/verify.md` has the post-install probes.

## 1. What breaks when the invariant breaks

A branch can be checked out in only one worktree at a time, so once the primary drifts onto a feature
branch `main` is either claimed by something disposable or unavailable:

- every other worktree's `git checkout main` fails with `'main' is already used by worktree at …`
- `gh pr merge --delete-branch` fails its local step **after the merge has landed** — the exit code
  says failure while the PR says merged, and the local branch survives. This is the expensive one: it
  invites a retry of a merge that already happened.

## 2. What git already enforces

If the primary keeps `main` checked out, git refuses to put `main` in a second worktree. Confirm in
the target repo before writing anything:

```bash
git worktree add /tmp/probe main    # fatal: 'main' is already used by worktree at ...
```

What it does *not* cover, and the only reason to install more: `git switch
--ignore-other-worktrees main` (opts out), `git switch --detach main` (takes the commit without
claiming the branch), and committing in the primary on any branch, which git never objects to.

## 3. The refusing hooks

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

Install that body under **both** `pre-commit` and `pre-merge-commit`: `pre-commit` does not run for
merge commits, so `git merge --no-ff` lands on `main` untouched without the second name. A squash
merge is caught by `pre-commit`, since it ends in an ordinary commit.

The merge branch keys on `${0##*/}`, not `MERGE_HEAD`, which does not exist yet when the hook runs;
`$op` keeps the printed bypass matching the command the user actually typed. Both in
`references/evidence.md`.

**That message assumes the all-four install of section 4.** Installing only this family →
`--no-verify` *does* bypass, so the last two lines must instead read
`if you truly meant this, git commit --no-verify bypasses it.` A hook that misstates its own bypass
is worse than one with no bypass line: it is read exactly once, by someone deciding what to do next.
Decide which install you want first — it changes the hook body, not just the file list.

`post-checkout` warns when the primary leaves `main` and **must exit 0**: exiting non-zero reports an
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

**The only hook that warns rather than refuses, so its message carries the whole fix** — a refusal
leaves the user where they were, a warning arrives after the state it describes is true.
`git switch main` is the entire remedy, and the `reference-transaction` hook permits it: a `HEAD`
update is not a `refs/heads/*` transaction.

## 4. The second mechanism — neither one is enough alone

`pre-commit` never runs for `cherry-pick`, `revert` or `reset --hard`, so all three land on `main` in
the primary untouched. Measured: `main` went from 1 commit to 3 with only the section-3 hooks. A
`reference-transaction` hook catches them, because they are ref updates:

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

Two lines carry this hook, and both are easy to "simplify" wrongly:

- **The allowlist must stay an allowlist.** Only `pull`, `merge` and `fetch` may move a branch here;
  everything else, *including an unset action*, is refused. The destructive paths fall through to
  that default rather than failing a match, so a presence check on `GIT_REFLOG_ACTION` inverts it.
- **`[ "$old" = "$new" ]` is the invariant restated**, not an exception: a transaction where the ref
  does not move cannot change the commit graph. Dropping it refuses `git stash`, `reset --hard HEAD`
  and `--abort` — the guardrail's own teardown and the usual recovery route.

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

**Install all four hooks**, each carrying the `managed-by` marker.

**"Refused" means the ref did not move, not that nothing happened.** Git writes the index and
working tree first, then opens the transaction the hook aborts, so a refused `reset --hard HEAD~1`
still destroys uncommitted work. State the guarantee as *the commit graph is protected*, never as
*the command is a no-op*. Recovery: `git reset --hard HEAD` (v4+), or
`git restore --source=HEAD --staged --worktree .`, which touches no refs and so works under v3 too —
prefer it for an install you have not verified. A refused `merge` or `cherry-pick` also leaves the
primary mid-operation: `--abort` where one exists, that reset otherwise.

Two costs of installing all four, both worth saying out loud:

- **`--no-verify` no longer bypasses.** The escape becomes `git -c core.hooksPath=/dev/null …`, not
  discoverable from the error, so it goes *in* the message — and in the section 3 body too, which
  otherwise ships advice this hook makes false.
- **A branch *switch* still cannot be blocked.** Guarding `HEAD` here would refuse `git worktree add
  -b` as well: it and `git switch` present identical `PWD`, `GIT_DIR`, `rev-parse --git-dir` and
  environment, so there is nothing to discriminate on. `post-checkout` after the fact is the only
  option.

## 5. Where the hooks live

Hooks live in the common git dir, so **one install covers every worktree**. **Resolve that path with
`cd … && pwd`, never by string-pasting:** `git rev-parse --git-common-dir` returns a path *relative
to the current directory* inside the primary — `.git` at the top level, `../.git` one directory down
— and absolute only from a linked worktree. Pasting the relative form into an `install` target writes
the hooks wherever your shell happens to be standing.

```bash
H="$(cd "$(git rev-parse --git-common-dir)" && pwd)/hooks"
install -m 755 <refuse>  "$H/pre-commit"
install -m 755 <refuse>  "$H/pre-merge-commit"
install -m 755 <reftxn>  "$H/reference-transaction"
install -m 755 <warn>    "$H/post-checkout"
```

To version the hooks instead, keep a tracked `.githooks/` and `git config core.hooksPath .githooks`
— but **a relative `core.hooksPath` resolves against each worktree's own top level**, so the hooks
vanish on any branch that doesn't carry the directory. Usually harmless (the primary sits on `main`,
which has it) and occasionally baffling; an absolute path fires everywhere and is not committable.
Either way `core.hooksPath` is **not carried by a clone**, which is why the server-side layer exists.

## 6. Upgrading an existing install

Most repos that want this already have *something*, usually an older `pre-commit` predating the
`cherry-pick` / `revert` findings. **Re-running must be safe on those.** Every hook this skill writes
carries a marker as its second line, and that marker is the whole upgrade mechanism:

```sh
# managed-by: setup-git-guardrail v5 — re-run the skill to update; edits here are overwritten
```

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

**Print `$H` and check it before trusting the verdicts.** Rewriting the relative
`--git-common-dir` against `--show-toplevel` resolves to `<toplevel>/../.git/hooks` one directory
down; that path does not exist, so every hook classifies as **absent**, a guarded repo reads as
unguarded, and the install writes four hooks outside the repo where nothing runs them — silent both
ways. **An `absent` verdict on a repo you believe is installed means the path is wrong, not the
hooks.**

| State | Action |
|---|---|
| absent | Install it |
| marker, older version | Replace in place — `references/evidence.md` says what each bump changed |
| marker, current version | Leave alone — re-running is a no-op |
| **no marker** | **Never overwrite.** Someone wrote it by hand |

An unmanaged hook is the `ja-changelog` case: hand-written, carrying the motivating incident in its
own comments, and that commentary is worth more than the code. Copy it to
`<hook>.pre-guardrail.bak`, show the diff against what the skill would install, let the user choose.
**Never merge the two automatically.**

The usual result is a partial upgrade: two unmanaged hooks left alone and the two missing files
(`pre-merge-commit`, `reference-transaction`) added alongside, which closes the `cherry-pick` /
`revert` / `merge --no-ff` holes without touching anything hand-written. Say which files you added
and which you left, by name.

## 7. Verify — test the failure path

**Changing anything in this skill? Run `scripts/test-guardrail.sh` first.** It builds a throwaway
upstream + primary + worktree under `mktemp -d`, installs the four hook bodies *extracted from this
file* — so the suite cannot drift from the hooks it documents — and asserts the section 4 table, the
`pull --ff-only` allowlist, the `git stash` round-trip, the `post-checkout` warning and its remedy,
the drift check from all four vantage points, and the hooks-path resolution. 50 assertions, no real
repository touched, exit 0 when they all hold.

For a repo you just installed into, run the probes in `references/verify.md`. Two traps it exists
for: the pass criterion is the **sha**, not the error message, and the obvious `git pull --ff-only`
test is **vacuous** on an up-to-date primary, where no ref transaction fires and the hook is never
consulted.

## 8. Server-side, the layer that cannot be bypassed

Local hooks are per-machine and per-clone. Branch protection is the only enforcement that survives a
fresh clone or a colleague's laptop. **Confirm before running it** — it changes the repo for everyone
with access, and `enforce_admins` locks the owner out of their own direct pushes, which is the point
but their call.

```bash
gh api -X PUT repos/<owner>/<repo>/branches/main/protection \
  -F 'required_pull_request_reviews[required_approving_review_count]=0' \
  -F 'enforce_admins=true' -F 'required_status_checks=null' -F 'restrictions=null'

gh api repos/<owner>/<repo>/branches/main/protection \
  --jq '{admins: .enforce_admins.enabled, reviews: .required_pull_request_reviews.required_approving_review_count}'
```

Every flag is `-F`, not `-f` — `-f` sends an integer field as a string and 422s. Read the protection
back afterwards, and never through a pipe: `gh api … | tail -1` reports `tail`'s exit status, not the
API's. Both in `references/evidence.md`.

## 9. Drift is announced once, into a terminal nobody re-reads

`post-checkout` fires the instant the primary leaves `main` and prints the remedy. Right moment,
wrong durability: it goes to whoever ran `git switch`, scrolls away, and is never restated — while
the section 1 consequence arrives hours later, in another session, with nothing on screen connecting
the two. So the check also has to run at the *start of a session*, outside git's hook set.

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

**`SessionStart` is one of only three events whose stdout reaches the agent's context** — with
`UserPromptSubmit` and `UserPromptExpansion`; everywhere else it goes to the debug log. Hence not a
`PreToolUse` hook: the finding has to reach the agent about to do the work, not the user who already
knows. It cannot block a session, and a non-zero exit only shows stderr, so a broken script degrades
to silence.

Omit the `matcher` so it fires on `startup`, `resume`, `clear`, `compact` and `fork` — the
rebuild-the-context cases are exactly when the fact needs restating.

Editing that script → read `references/evidence.md` first: the default branch must come from
`origin/HEAD` rather than the literal `main`, a detached HEAD must be named, and the happy path must
exit 0.

This reports; it never refuses. With `post-checkout` the drift is stated twice and prevented neither
time.

## Limits — say these out loud when you install

- `-c core.hooksPath=/dev/null` bypasses all of it. Guardrail, not a boundary.
- **The commit graph is protected, not the working tree.** `reset --hard` in the primary still
  destroys uncommitted work. Recover with `git reset --hard HEAD` (v4+) or
  `git restore --source=HEAD --staged --worktree .` (any version) — check `git status` first.
- A refused `merge` or `cherry-pick` leaves the primary mid-operation. From v4 `--abort` clears it;
  under v3 `--abort` was itself refused and the primary stayed wedged.
- Hooks are not cloned; every machine needs the install run again.
- No hook can stop a branch *switch*. Drift off `main` is warned about, never prevented: from v5 the
  warning carries the fix and section 9 restates it later, but neither is enforcement, and the
  primary can sit drifted indefinitely if both are ignored.
- `git commit --amend` fires no ref transaction, so `reference-transaction` is blind to it. That is
  why the `pre-commit` family stays even after installing the stronger hook.
- Prior art here: `erlia/ja-changelog/.githooks/` — the `pre-commit` / `post-checkout` pair with the
  motivating incident in the hook's own comments. Read it first; it predates the `cherry-pick` /
  `revert` finding and does not cover those.
