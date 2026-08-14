#!/bin/sh
# Claude Code SessionStart hook — report a primary clone that has drifted off its parked branch.
#
# Wiring, and why this exists at all, are in SKILL.md section 9. The short version: post-checkout
# warns at the instant of drift, into the terminal of whoever caused it. Nothing ever says it again.
# SessionStart is one of only three events whose stdout is added to the agent's context, so this
# line is read by the agent rather than printed past the user.
#
# Read-only: blocks nothing, writes nothing, touches no ref, and always exits 0. That last part is
# belt-and-braces — SessionStart cannot block a session, and a non-zero exit only shows stderr to
# the user — but an exit-1 hook still logs noise every session, and the obvious one-liner form
# (`[ test ] && echo ...`) ends on a false test on the happy path and does exactly that.

git rev-parse --git-common-dir >/dev/null 2>&1 || exit 0    # not a repo: nothing to say

# The primary clone is the parent of the common git dir. Resolve it with cd/pwd, never by pasting
# the string: --git-common-dir is RELATIVE inside the primary ('.git' at the top level, '../.git'
# one directory down) and absolute only from a linked worktree. Verified to give the same answer
# from the primary, from a subdirectory of it, and from any worktree.
primary=$(dirname "$(cd "$(git rev-parse --git-common-dir)" && pwd)")

# What it SHOULD be parked on. Hardcoding 'main' misfires on every repo whose default is something
# else — measured: of 19 local repos, one parks on 'Dev' — and a guardrail that cries wolf at a
# correctly-parked clone is one nobody reads. origin/HEAD is set by `git clone`; 'main' is the
# fallback for the repo that has somehow lost it.
parked=$(git -C "$primary" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
parked=${parked#origin/}
parked=${parked:-main}

# What it IS on. symbolic-ref fails on a detached HEAD, and that is drift too: `git switch --detach`
# takes the commit without claiming the branch, one of the two paths git's own worktree lock does
# not cover (section 2). Reporting nothing there would be the quietest possible failure.
branch=$(git -C "$primary" symbolic-ref --short HEAD 2>/dev/null) || branch="detached HEAD"

[ "$branch" = "$parked" ] || cat <<EOF
⚠ primary clone $primary is on '$branch', not '$parked' — no worktree can check out '$parked' while
  it is, and a merge that deletes its branch will fail its local step after the merge has landed.
  Fix:  git -C $primary switch $parked
EOF
exit 0
