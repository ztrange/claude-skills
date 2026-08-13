---
name: install-guardrails
description: >-
  Install the git guardrails that keep `main` clean and work inside worktrees: a
  `reference-transaction` hook that refuses commits on `main` even under `--no-verify`, and
  optionally GitHub branch protection so a push is refused server-side too. Use when the user says
  "install guardrails", "protect main", "prevent commits to main", "stop me committing to main",
  "add the git hooks", "set up branch protection", or "instala los guardrails". Checks what git
  already enforces before installing anything, scopes the hook so it does not break `git pull` on
  the primary clone, verifies by testing the failure path, and states plainly where the guardrail
  can be bypassed.
---

# Install guardrails — main stays clean, work stays in worktrees

**Install only the gap.** Git already refuses most of what people write hooks for, and a hook that
duplicates a native check is one more thing to debug. Check first, install second.

**None of this is a security boundary.** `git -c core.hooksPath=/dev/null commit` skips every hook
here. It stops accidents, not intent. Say so when you install it, so nobody builds a policy on top
of it.

## 1. Check what git already enforces

If the primary clone keeps `main` checked out, git already refuses to put `main` in a second
worktree — no hook needed:

```bash
git worktree add /tmp/probe main    # fatal: 'main' is already used by worktree at ...
```

Confirm it in the target repo before writing anything. Two holes remain, and they are the only
reason to go further:

- `git switch --ignore-other-worktrees main` — explicitly opts out of the native check.
- `git switch --detach main` — lands on the commit without claiming the branch.
- If the primary clone is *not* parked on `main`, there is no native guard at all.

## 2. Pick the mechanism

| Hook | Can it abort? | Skipped by `--no-verify`? |
|---|---|---|
| `reference-transaction` (`prepared`) | Yes — aborts the ref update | **No** |
| `pre-commit` | Yes | Yes |
| `pre-push` | Yes | Yes |
| `post-checkout` | No — checkout already applied | n/a |
| `post-index-change` | No — exit status ignored | n/a |

`reference-transaction` is the one to use. It is the only hook `--no-verify` does not skip, and
because a commit *is* a ref update it catches the commit itself rather than the ceremony around it.

Hooks live in the common git dir, so **one install covers every worktree** of that repo.

## 3. The discriminator that makes it safe

Refusing every update to `refs/heads/main` also refuses `git pull` on the primary clone — which is
how you keep `main` current, so the guardrail would break the workflow it protects. The hook must
tell a local commit from a remote sync. `GIT_REFLOG_ACTION` does that:

| Operation | `GIT_REFLOG_ACTION` |
|---|---|
| `git commit`, including `--no-verify` and `--amend` | unset |
| `git merge --ff-only origin/main` | `merge origin/main` |
| `git pull --ff-only` | `pull --ff-only` |

So: refuse when it is unset, allow when it is set. `git fetch` never touches `refs/heads/main` at
all — it writes `refs/remotes/*` — so it is unaffected either way.

## 4. Install

```bash
cat > "$(git rev-parse --git-common-dir)/hooks/reference-transaction" <<'EOF'
#!/bin/sh
# Refuse commits that land on main. Remote syncs (merge/pull) set GIT_REFLOG_ACTION; a
# commit does not, which is the only reliable way to tell them apart at this point.
[ "$1" = prepared ] || exit 0
while read -r old new ref; do
  case "$ref" in
    refs/heads/main|refs/heads/master)
      if [ -z "${GIT_REFLOG_ACTION-}" ]; then
        echo "guardrail: refusing to commit on ${ref#refs/heads/}." >&2
        echo "  Work happens in a worktree on its own branch:" >&2
        echo "    git worktree add ../wt-<name> -b <branch>" >&2
        exit 1
      fi
      ;;
  esac
done
exit 0
EOF
chmod +x "$(git rev-parse --git-common-dir)/hooks/reference-transaction"
```

If the repo sets `core.hooksPath`, that path wins and the hook above is never read. Point it
somewhere absolute — **a relative `core.hooksPath` resolves against each worktree's own top level**,
so a tracked `.githooks/` silently vanishes on any branch that does not carry the directory, and
the guardrail disappears exactly when someone switches to an odd branch.

## 5. Verify — test the failure path

Installing is not evidence. Run all four, in the repo you just installed into:

```bash
git switch main && git commit --allow-empty -m probe              # must be REFUSED
git commit --allow-empty --no-verify -m probe                     # must be REFUSED
git pull --ff-only                                                # must SUCCEED
git switch -c probe-branch && git commit --allow-empty -m probe   # must SUCCEED
git switch main && git branch -D probe-branch
```

The second line is the one that matters — it is the whole reason for choosing this hook over
`pre-commit`. If it succeeds, the hook is not installed where you think it is: check
`git config core.hooksPath` and `git rev-parse --git-common-dir`.

## 6. Server-side, the layer that cannot be bypassed

Local hooks are per-machine and per-clone: a fresh clone has none, and a colleague's laptop has
none. Branch protection is the only enforcement that survives that.

```bash
gh api -X PUT repos/<owner>/<repo>/branches/main/protection \
  -f 'required_pull_request_reviews[required_approving_review_count]=0' \
  -F 'enforce_admins=true' -F 'required_status_checks=null' -F 'restrictions=null'
```

**Confirm before running it.** This changes the repo's settings for everyone with access, not just
the local machine, and `enforce_admins=true` locks the user out of their own direct pushes — which
is the point, but it should be their decision, not a side effect of installing a hook.

## Limits — say these out loud when you install

- `-c core.hooksPath=/dev/null` bypasses every hook. Guardrail, not a boundary.
- Hooks are not cloned. Each machine and each fresh clone needs this run again.
- The hook keys on the branch *name*. A repo whose default branch is neither `main` nor `master`
  needs the `case` line edited.
- It refuses any ref update to `main` with no reflog action, so an exotic local operation that
  leaves `GIT_REFLOG_ACTION` unset gets blocked too. That fails loudly, which is the right
  direction — but say it, so the message is recognised rather than debugged.
