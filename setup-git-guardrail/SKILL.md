---
name: setup-git-guardrail
description: >-
  Install git hooks that keep the primary clone parked on `main` and push all work into worktrees:
  a `pre-commit` and `pre-merge-commit` that refuse any commit made in the primary clone, a
  `reference-transaction` hook that catches the paths those never see (`cherry-pick`, `revert`,
  `reset --hard`, `--no-verify`), and a `post-checkout` that says so loudly when the primary
  drifts off `main`. Use when the user says "set up git guardrails", "install guardrails",
  "protect main", "prevent commits to main", "stop me committing in the primary clone", "add the
  git hooks", "set up branch protection", "update the git hooks", or "instala los guardrails". Checks what git already
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
# managed-by: setup-git-guardrail v3 — re-run the skill to update; edits here are overwritten
git_dir=$(cd "$(git rev-parse --git-dir)" && pwd)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$git_dir" = "$common_dir" ] || exit 0     # linked worktree: this is where work belongs
echo "  refused: this is the primary clone; it exists to sit on main and hold it." >&2
echo "    git worktree add .claude/worktrees/<task> -b claude/<task> origin/main" >&2
echo "    to update the primary, never merge:  git pull --ff-only" >&2
echo "    --no-verify does NOT bypass this; the escape is:" >&2
echo "    git -c core.hooksPath=/dev/null commit ..." >&2
exit 1
```

**That message is written for the all-four install of section 4, which is the recommended one.**
Installing only this family? Then `--no-verify` *does* bypass, and those last two lines have to say
so instead — `if you truly meant this, git commit --no-verify bypasses it.` Ship whichever is true
of the install you actually performed. A hook that misstates its own bypass is worse than one with
no bypass line at all: it is read exactly once, by someone deciding what to do next.

`post-checkout` warns when the primary leaves `main`, and **must exit 0**. Exiting non-zero does
not undo the checkout — it reports an error about a switch that already succeeded, which lies in
the one place someone is reading. Args: `$1` old HEAD, `$2` new HEAD, `$3` = 1 for a branch switch.

```sh
#!/bin/sh
# managed-by: setup-git-guardrail v3 — re-run the skill to update; edits here are overwritten
[ "$3" = "1" ] || exit 0
git_dir=$(cd "$(git rev-parse --git-dir)" && pwd)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$git_dir" = "$common_dir" ] || exit 0
branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = main ] || echo "  ⚠ primary clone is on '$branch', not main" >&2
exit 0
```

`pre-commit` does not run for merge commits — git calls `pre-merge-commit` for those, so
`git merge --no-ff` lands on `main` untouched without it. Install the same body under both names.
A squash merge is caught by `pre-commit`, since it ends in an ordinary commit.

On its own this family is bypassed by `--no-verify`. Documenting that bypass in the message makes
the common accident loud without standing between someone and a deliberate act — a defensible
choice, and the reason the section-3-only variant exists. Section 4 closes that bypass along with
three paths these hooks never see. Decide which of the two behaviours is wanted before installing,
because the choice changes the hook body, not just which files get written.

## 4. The second mechanism — neither one is enough alone

`pre-commit` never runs for `cherry-pick`, `revert` or `reset --hard`, so all three land on `main`
in the primary clone untouched. Measured: `main` went from 1 commit to 3 with the hooks above
installed. A `reference-transaction` hook catches exactly those, because they are ref updates:

```sh
#!/bin/sh
# managed-by: setup-git-guardrail v3 — re-run the skill to update; edits here are overwritten
[ "$1" = prepared ] || exit 0
gd=$(cd "$(git rev-parse --git-dir)" && pwd); cm=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$gd" = "$cm" ] || exit 0
while read -r old new ref; do
  case "$ref" in refs/heads/*) ;; *) continue ;; esac
  [ "$old" = 0000000000000000000000000000000000000000 ] && continue   # branch creation, and worktree add -b
  case "${GIT_REFLOG_ACTION-}" in pull*|merge*|fetch*) continue ;; esac  # remote sync, allowlisted
  echo "  refused: '${GIT_REFLOG_ACTION:-commit}' would move ${ref#refs/heads/} in the primary clone" >&2
  echo "    work belongs in a worktree; the primary sits on main and holds it:" >&2
  echo "    git worktree add .claude/worktrees/<task> -b claude/<task> origin/main" >&2
  echo "    --no-verify does NOT bypass this; the escape is:" >&2
  echo "    git -c core.hooksPath=/dev/null <cmd> ..." >&2
  exit 1
done
exit 0
```

**The allowlist is the load-bearing detail, and it must stay an allowlist.** Only `pull`, `merge`
and `fetch` may move a branch here; everything else, *including an unset action*, is refused.
Measured on git 2.55.0, this is what the hook actually sees:

| Command | `GIT_REFLOG_ACTION` at the ref transaction |
|---|---|
| `commit`, `cherry-pick`, `revert`, `reset --hard` | **unset** |
| `merge --no-ff` / `--ff-only` | `merge <ref>` |
| `pull --ff-only` | `pull --ff-only` |

So the destructive paths are refused by *falling through* to the default, not by failing a match.
That is exactly why the test must be an allowlist and not a presence check like
`[ -n "$GIT_REFLOG_ACTION" ] && continue`. The two behave identically on this version — a presence
check happens to refuse `cherry-pick` here, since git leaves the variable unset — but it inverts
the default: it permits anything git chooses to label, now or in a future version, and the failure
mode is silent permission rather than a noisy refusal. Default to refusing and enumerate the
exceptions.

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

Install all four hooks, each carrying the `managed-by` marker from section 6. Verified together: every refusal above holds and all three permitted
operations work.

### "Refused" means the ref did not move. It does not mean nothing happened

**Git writes the index and the working tree first, then opens the ref transaction the hook
aborts.** Every "refused" in the table above is a claim about the commit graph only. Measured, with
all four hooks installed and an uncommitted edit in the primary: `git reset --hard HEAD~1` was
refused and `main` never moved — and the uncommitted edit was gone, with the index left matching
`HEAD~1` against an unmoved `HEAD`. A failed `pull --ff-only` behaves the same way, leaving fetched
content staged.

So state the guarantee as **the commit graph is protected**, never as *the command is a no-op*.
Recovery is `git restore --source=HEAD --staged --worktree .`, which touches no refs and so does
not trip the hook. `git reset --hard HEAD` does not work here — it opens a ref transaction even
when old and new are identical, and is refused like any other.

The interrupted-operation commands are the same trap one level up. A refused `merge --no-ff` or
`cherry-pick` leaves `MERGE_HEAD` / `CHERRY_PICK_HEAD` behind, and **`git merge --abort` and
`git cherry-pick --abort` are themselves refused by this hook** — the guardrail blocks its own
teardown and the primary stays wedged mid-merge. The way out is `--quit` (`git merge --quit`,
`git cherry-pick --quit`), which drops the state without touching refs, followed by the `restore`
above.

Two things this costs, both worth saying out loud when installing:

- **`--no-verify` no longer bypasses.** The escape becomes `git -c core.hooksPath=/dev/null …`,
  which is not discoverable from the error message. Put it in the message — and in the section 3
  body too, which otherwise ships advice that this hook makes false.
- **A branch *switch* still cannot be blocked.** Guarding `HEAD` here refuses `git worktree add -b`
  as well: that command and `git switch` present the hook with identical `PWD`, `GIT_DIR`,
  `rev-parse --git-dir` and environment, so there is nothing to discriminate on. `post-checkout`
  warning after the fact remains the only option.

## 5. Where the hooks live

Hooks live in the common git dir, so **one install covers every worktree** of the repo:

**Resolve that path with `cd … && pwd`, never by string-pasting it.** `git rev-parse
--git-common-dir` returns a path *relative to the current directory* when run inside the primary
clone — `.git` at the top level, `../.git` one directory down — and an absolute path only from a
linked worktree. Pasting the relative form into an `install` target writes the hooks wherever your
shell happens to be standing. The hook bodies above already do this correctly; so must the
installer:

```bash
H="$(cd "$(git rev-parse --git-common-dir)" && pwd)/hooks"
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

## 6. Upgrading an existing install

Most repos that want this already have *something* — usually an older `pre-commit` that predates
the `cherry-pick` / `revert` findings. **Re-running the skill must be safe on those.**

Every hook this skill writes carries a marker as its second line:

```sh
# managed-by: setup-git-guardrail v3 — re-run the skill to update; edits here are overwritten
```

That marker is the whole upgrade mechanism. Classify each of the four hook names before writing
anything:

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
       [ "$v" = 3 ] && echo "$h: v$v current -> leave" || echo "$h: v$v outdated -> replace"
  else echo "$h: UNMANAGED  -> do not touch; report it"
  fi
done
```

**Print `$H` and check it before trusting the classification.** The two branches above are not
interchangeable: `--git-common-dir` is relative inside the primary clone, so the older form —
`H=${H:-$(git rev-parse --git-common-dir)/hooks}` then rewriting non-absolute paths against
`--show-toplevel` — resolves to `<toplevel>/../.git/hooks` when run one directory down. That
directory does not exist, so every hook classifies as **absent**, a fully-guarded repo reads as
unguarded, and the install then writes four hooks outside the repo where nothing ever runs them.
Silent in both directions. An `absent` verdict on a repo you believe is installed means the path is
wrong, not the hooks.

**v2 → v3 replaces all four bodies.** v2's `pre-commit` told the reader that `--no-verify` bypasses
it, which the `reference-transaction` hook installed alongside makes false; v3 carries the real
escape, and the `reference-transaction` body gained the same lines. A v2 install is not merely
stale, it is misleading in the one place someone reads it, so replace rather than leave.

The four outcomes, and the only one that needs judgement:

| State | Action |
|---|---|
| absent | Install it |
| marker, older version | Replace in place |
| marker, current version | Leave alone — re-running the skill is a no-op |
| **no marker** | **Never overwrite.** Someone wrote it by hand |

An unmanaged hook is the `ja-changelog` case: a hand-written `pre-commit` carrying the incident
that motivated it in its own comments. That commentary is worth more than the code. Copy it to
`<hook>.pre-guardrail.bak`, show the user the diff against what the skill would install, and let
them choose. Do not merge the two automatically — a hook that silently became something else is
worse than one that is out of date.

The common real-world result is a partial upgrade: two unmanaged hooks left in place, and the two
missing files (`pre-merge-commit`, `reference-transaction`) added alongside. That closes the
`cherry-pick` / `revert` / `merge --no-ff` holes without touching anything hand-written. Say which
files you added and which you left, by name.

## 7. Verify — test the failure path

**Changing anything in this skill? Run `scripts/test-guardrail.sh` first.** It builds a throwaway
upstream + primary + worktree under `mktemp -d`, installs the four hook bodies *extracted from this
file* — so the suite cannot drift from the hooks it documents — and asserts every row of the
section 4 table, the sharp edges above, the `pull --ff-only` allowlist, and the hooks-path
resolution. It touches no real repository. 23 assertions, exit 0 when they all hold.

That covers development. The rest of this section is the manual check for a repo you just installed
into, where the throwaway lab is not the thing you care about. Three things make it work, and
skipping any of them turns it into theatre:

- **The pass criterion is the sha, not the error message.** "Refused" and "`main` didn't move" are
  different claims and only the second is the invariant (section 4: the tree is written before the
  ref aborts, so a refusal is never a no-op). Record `git rev-parse main` before and after, compare
  at the end.
- **The primary must be clean before you start**, because these probes destroy uncommitted work in
  it. Check `git status --porcelain` is empty and stop if it isn't.
- **The probes need a ref ahead of `main`**, and creating one in the primary is circular — the
  hooks you just installed refuse it. Build it in a worktree, which doubles as two of the tests.

```bash
cd <primary>
[ -z "$(git status --porcelain)" ] || { echo "primary is dirty — stop"; exit 1; }
BEFORE=$(git rev-parse main)

git worktree add /tmp/gr-probe -b probe/guardrail main   # must SUCCEED — old=0000 allowlist
git -C /tmp/gr-probe commit --allow-empty -m probe       # must SUCCEED — work belongs here
PROBE=$(git -C /tmp/gr-probe rev-parse HEAD)

git commit --allow-empty -m probe                # must be REFUSED
git commit --allow-empty --no-verify -m probe    # must be REFUSED — needs reference-transaction
git commit --amend --no-edit                     # must be REFUSED — pre-commit only
git merge --no-ff probe/guardrail                # must be REFUSED — needs pre-merge-commit
git merge --quit                                 # teardown: --abort is itself refused
git cherry-pick "$PROBE"                         # must be REFUSED — reference-transaction only
git cherry-pick --quit                           # teardown: --abort is itself refused
git revert --no-edit HEAD                        # must be REFUSED — reference-transaction only
git reset --hard HEAD~1                          # must be REFUSED — DESTROYS the working tree

git restore --source=HEAD --staged --worktree .  # teardown: reset --hard HEAD would be refused
git worktree remove --force /tmp/gr-probe && git branch -D probe/guardrail

[ "$(git rev-parse main)" = "$BEFORE" ] && [ -z "$(git status --porcelain)" ] \
  && echo "PASS: main unmoved at $BEFORE, tree clean" || echo "FAIL"
```

Avoid `${PIPESTATUS[0]}` and friends if you capture exit codes here — it is a bashism that
silently expands to nothing under zsh, which is the default shell on macOS. Test `$?` directly
without a pipe, or spell it `${pipestatus[1]}` under zsh.

### `pull --ff-only` is the regression that matters, and the obvious test for it is vacuous

A hook that refuses *every* update to `refs/heads/main` passes every check above and quietly bricks
the primary clone's only job. Running `git pull --ff-only` in a primary that is already current
does not catch it: **no ref transaction fires, so the hook is never consulted.** Measured, with an
allowlist-free hook deliberately installed: up-to-date primary reported `Already up to date` and
exit 0 — passing — while the same hook on a primary genuinely behind refused the fast-forward and
pinned `main` in place. The one test the section exists for is the one that self-certifies.

Being current is the *normal* state of a clone whose whole job is sitting on `main`, so create the
condition instead of hoping for it. Do it in a throwaway clone, since the alternatives all require
moving `origin/main`, which is the thing being prevented:

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

Local hooks are per-machine and per-clone. Branch protection is the only enforcement that survives
a fresh clone or a colleague's laptop:

```bash
gh api -X PUT repos/<owner>/<repo>/branches/main/protection \
  -F 'required_pull_request_reviews[required_approving_review_count]=0' \
  -F 'enforce_admins=true' -F 'required_status_checks=null' -F 'restrictions=null'
```

**Every flag here is `-F`, and that is load-bearing.** `-f` is `--raw-field`, which sends the value
as a JSON *string*; `required_approving_review_count` must be a typed integer, so `-f` on that one
field fails with `422: For 'properties/required_approving_review_count', "0" is not an integer`.
`-F` is `--field`, which infers the type, and it does so correctly through the `a[b]` bracket
syntax — verified on `gh` 2.96.0, which serialises the body above as
`"required_approving_review_count": 0`. No heredoc or `--input -` is needed to get an integer
through.

**Confirm before running it.** It changes the repo for everyone with access, and `enforce_admins`
locks the owner out of their own direct pushes — the point, but their call to make.

**Then read the protection back**, because a request that never applied still prints nothing
alarming if its output was piped:

```bash
gh api repos/<owner>/<repo>/branches/main/protection \
  --jq '{admins: .enforce_admins.enabled, reviews: .required_pull_request_reviews.required_approving_review_count}'
```

`gh api` does exit non-zero on a 4xx — measured, exit 1 on a 404 — so a bare call fails loudly.
What hides the failure is a pipe: `gh api … | tail -1` reports the exit status of `tail`, which is
0 no matter what the API said. Same trap as `${PIPESTATUS[0]}` in section 7, one layer up.

## Limits — say these out loud when you install

- `-c core.hooksPath=/dev/null` bypasses all of it. Guardrail, not a boundary.
- **What is protected is the commit graph, not the working tree.** A refused command has already
  written the index and the worktree by the time the ref transaction aborts, so `reset --hard` in
  the primary still destroys uncommitted work. Recover with `git restore`, never `reset --hard HEAD`.
- Hooks are not cloned; every machine needs the install run again.
- No hook can stop a branch *switch*. `post-checkout` only notices after the fact, and guarding
  `HEAD` in `reference-transaction` also refuses `git worktree add -b` — the two are
  indistinguishable there. Drift off `main` is warned about, never prevented.
- `git commit --amend` fires no ref transaction at all, so `reference-transaction` is blind to it.
  That is why the `pre-commit` family stays even after installing the stronger hook.
- Prior art in this setup: `erlia/ja-changelog/.githooks/` — the `pre-commit` / `post-checkout`
  pair, with the incident that motivated it recorded in the hook's own comments. Read it first. It
  predates the `cherry-pick` / `revert` finding and does not cover those.
