#!/usr/bin/env bash
# Regression suite for the setup-git-guardrail hooks.
#
# Builds a throwaway upstream + primary clone + linked worktree under a temp dir, installs the four
# hook bodies EXTRACTED FROM SKILL.md, and asserts every row of the section 4 table plus the
# behaviours that are easy to regress. Touches no real repository.
#
#   ./scripts/test-guardrail.sh            # run
#   ./scripts/test-guardrail.sh -k         # keep the lab dir for poking at
#
# Exit 0 = all pass. Exit 1 = at least one failure, listed at the end.
#
# The bodies are extracted rather than duplicated on purpose: a copy here would drift from the
# skill silently, and a suite testing hooks nobody installs is worse than no suite.

set -uo pipefail

KEEP=0
[ "${1-}" = "-k" ] && KEEP=1

SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/SKILL.md"
[ -r "$SKILL" ] || { echo "cannot read $SKILL" >&2; exit 1; }

LAB=$(mktemp -d "${TMPDIR:-/tmp}/gr-lab.XXXXXX")
UP="$LAB/upstream" PRI="$LAB/primary" WT="$LAB/worktree"
cleanup() { [ "$KEEP" = 1 ] && { echo "lab kept at $LAB"; return; }; chmod -R u+w "$LAB" 2>/dev/null; rm -rf "$LAB"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED=()
ok()   { PASS=$((PASS+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED+=("$1"); printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2-}" ] && printf '        %s\n' "$2"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# --- extract the canonical hook bodies from SKILL.md -------------------------------------------
# Every body carries the managed-by marker as its second line. Pull each fenced sh block that has
# one and is more than a stub, then classify by content.
extract() {
  awk '
    /^```sh$/      { inb=1; buf=""; n=0; next }
    /^```$/ && inb { if (n > 2 && buf ~ /managed-by: setup-git-guardrail/) printf "%s\036", buf; inb=0; next }
    inb            { buf = buf $0 "\n"; n++ }
  ' "$SKILL"
}
MARKER_V=$(sed -n 's/^# managed-by: setup-git-guardrail v\([0-9]*\).*/\1/p' <<<"$(extract | tr '\036' '\n')" | head -1)
mkdir -p "$LAB/hooks"
while IFS= read -r -d $'\036' block; do
  case "$block" in
    *'refused: this is the primary clone'*) printf '%s' "$block" > "$LAB/hooks/refuse" ;;
    *'primary clone is on'*)                printf '%s' "$block" > "$LAB/hooks/warn" ;;
    *'[ "$1" = prepared ]'*)                printf '%s' "$block" > "$LAB/hooks/reftxn" ;;
  esac
done < <(extract)
for h in refuse warn reftxn; do
  [ -s "$LAB/hooks/$h" ] || { echo "could not extract '$h' body from SKILL.md" >&2; exit 1; }
  chmod 755 "$LAB/hooks/$h"
done
echo "extracted hook bodies from SKILL.md (marker version: v${MARKER_V:-?})"

# --git-dir / --git-common-dir are relative to the REPO, not to $PWD. Resolving them by string
# concatenation from the wrong cwd is the exact bug section 5 warns about; route every use here.
gitdir()    { (cd "$1" && cd "$(git rev-parse --git-dir)" && pwd); }
commondir() { (cd "$1" && cd "$(git rev-parse --git-common-dir)" && pwd); }

install_hooks() {  # $1 = repo, $2 = optional alternate reference-transaction body
  local h; h="$(commondir "$1")/hooks"
  install -m 755 "$LAB/hooks/refuse" "$h/pre-commit"
  install -m 755 "$LAB/hooks/refuse" "$h/pre-merge-commit"
  install -m 755 "${2:-$LAB/hooks/reftxn}" "$h/reference-transaction"
  install -m 755 "$LAB/hooks/warn"   "$h/post-checkout"
}

g()  { git -C "$PRI" "$@" >/dev/null 2>&1; }          # quiet, in the primary
gs() { git -C "$PRI" rev-parse main; }                 # current main sha

refused() {  # refused <desc> -- <git args...>   : must exit non-zero AND leave main unmoved
  local desc=$1; shift; [ "$1" = -- ] && shift
  local before; before=$(gs)
  if g "$@"; then bad "$desc" "command succeeded; expected refusal"
  elif [ "$(gs)" != "$before" ]; then bad "$desc" "refused but main moved $before -> $(gs)"
  else ok "$desc"; fi
}
allowed() { local desc=$1; shift; [ "$1" = -- ] && shift
  if git -C "$PRI" "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc" "expected success, got exit $?"; fi; }

# refused_saying <desc> <must-match ERE|-> <must-NOT-match ERE|-> -- <git args...>
#
# Everything refused() asserts, plus the content of the message. Two directions, and the NEGATIVE
# one is the point: a refused plain `git commit` must not advise `reset --hard`, because there the
# dirty tree is the user's own work and the advice would delete exactly what they tried to commit.
# refused() pipes stderr to /dev/null, so no assertion here could be made through it.
refused_saying() {
  local desc=$1 want=$2 avoid=$3; shift 3; [ "$1" = -- ] && shift
  local before out rc flat
  before=$(gs)
  out=$(git -C "$PRI" "$@" 2>&1 >/dev/null); rc=$?
  flat=$(tr '\n' '|' <<<"$out")
  if   [ "$rc" = 0 ];                                            then bad "$desc" "command succeeded; expected refusal"
  elif [ "$(gs)" != "$before" ];                                 then bad "$desc" "refused but main moved $before -> $(gs)"
  elif [ "$want"  != - ] && ! grep -Eq "$want"  <<<"$out";        then bad "$desc" "message lacks /$want/ — got: $flat"
  elif [ "$avoid" != - ] &&   grep -Eq "$avoid" <<<"$out";        then bad "$desc" "message offers /$avoid/, destructive here — got: $flat"
  else ok "$desc"; fi
}

# --- build the lab -----------------------------------------------------------------------------
mkdir -p "$UP" && git -C "$UP" init -q -b main .
git -C "$UP" config user.email t@example.com; git -C "$UP" config user.name t
for i in 1 2 3; do echo "line$i" > "$UP/f$i.txt"; git -C "$UP" add -A; git -C "$UP" commit -qm "c$i"; done
git clone -q "$UP" "$PRI"
git -C "$PRI" config user.email t@example.com; git -C "$PRI" config user.name t
install_hooks "$PRI"
BASE=$(gs)
echo "lab at $LAB (main=$(git -C "$PRI" rev-parse --short main))"

# --- a ref ahead of main, which the primary itself can no longer create -------------------------
head_ "Permitted operations (these must still work)"
allowed "git worktree add -b            (old=0000 allowlist)" -- worktree add "$WT" -b probe/guardrail main
git -C "$WT" config user.email t@example.com; git -C "$WT" config user.name t
# The probe commit must touch a file. An --allow-empty probe makes the cherry-pick below a no-op,
# which then "passes" the refusal assertion for the wrong reason and hides an allowlist regression.
echo probe > "$WT/probe.txt"; git -C "$WT" add -A
if git -C "$WT" commit -q -m probe 2>/dev/null; then ok "commit in a linked worktree"
else bad "commit in a linked worktree" "the whole point of the guardrail; hooks must exit 0 here"; fi
PROBE=$(git -C "$WT" rev-parse HEAD)

# git stash finishes by resetting the worktree to HEAD, which opens a no-op transaction on
# refs/heads/main. v3 refused it: the stash was created and the tree cleaned, but the command
# exited 1 and blamed 'commit'. The retry a user then makes reports "No local changes to save".
head_ "git stash (v3 refused this after it had already stashed)"
echo scratch > "$PRI/gr-stash.txt"; g add gr-stash.txt
SB=$(gs)
if git -C "$PRI" stash push -m gr-probe >/dev/null 2>&1; then
  if [ -z "$(git -C "$PRI" status --porcelain)" ] && [ "$(git -C "$PRI" stash list | wc -l | tr -d ' ')" = 1 ]; then
    ok "git stash push exits 0, stashes, and cleans the tree"
  else bad "git stash push exits 0, stashes, and cleans the tree" "exit 0 but state wrong: '$(git -C "$PRI" status --porcelain)' / $(git -C "$PRI" stash list | wc -l) entries"; fi
else bad "git stash push exits 0, stashes, and cleans the tree" "exit non-zero — the 'old = new' guard is missing from reference-transaction"; fi
allowed "git stash pop brings the work back" -- stash pop
[ "$(gs)" = "$SB" ] && ok "the stash round-trip left main unmoved" \
                    || bad "the stash round-trip left main unmoved" "main $SB -> $(gs)"
g rm -qf --cached gr-stash.txt; rm -f "$PRI/gr-stash.txt"; g restore --source=HEAD --staged --worktree .

head_ "Refused in the primary clone (section 4 table)"
# The message assertions ride along here rather than in a section of their own: the whole point of
# v4 is that these are the moments a message is read, so assert content where the refusal happens.
refused_saying "git commit"                  'refused: this is the primary clone' 'reset --hard|git restore' \
                                             -- commit --allow-empty -m probe
refused_saying "git commit --no-verify"      'DISCARDS uncommitted changes'       'cherry-pick --abort' \
                                             -- commit --allow-empty --no-verify -m probe
refused "git commit --amend"                 -- commit --amend --no-edit
refused_saying "git merge --no-ff"           'git merge --abort'                  - \
                                             -- merge --no-ff probe/guardrail
# TEARDOWN IS LOAD-BEARING between these. A refused merge/cherry-pick leaves the tree dirty, and
# git then refuses the NEXT probe on its own ("local changes would be overwritten by cherry-pick")
# before any hook runs. That still exits non-zero with main unmoved, so a bare refused() passes it
# while testing nothing. Assert the tree is clean before each probe rather than trusting it.
clean_or_die() { [ -z "$(git -C "$PRI" status --porcelain)" ] && return 0
  bad "teardown before '$1'" "tree still dirty: $(git -C "$PRI" status --porcelain | tr '\n' ' ')"; }
g merge --abort;       clean_or_die "git cherry-pick"
refused_saying "git cherry-pick"             'git cherry-pick --abort'            - \
                                             -- cherry-pick "$PROBE"
g cherry-pick --abort; clean_or_die "git revert"
refused_saying "git revert"                  'DISCARDS uncommitted changes'       'cherry-pick --abort' \
                                             -- revert --no-edit HEAD
g reset --hard HEAD;   clean_or_die "git reset --hard"
refused "git reset --hard"                   -- reset --hard HEAD~1
g reset --hard HEAD
git -C "$PRI" merge --squash probe/guardrail >/dev/null 2>&1
refused_saying "git merge --squash + commit" 'git merge --abort \|\| git reset'   - \
                                             -- commit -m probe
g reset --hard HEAD; rm -f "$PRI/f4.txt"

# --- documented sharp edges: assert them, so a git change that fixes them shows up here ---------
head_ "Documented sharp edges (section 4: refused != no-op)"
echo "PRECIOUS" >> "$PRI/f1.txt"
g reset --hard HEAD~1
if grep -q PRECIOUS "$PRI/f1.txt" 2>/dev/null; then
  bad "reset --hard destroys uncommitted work" "it no longer does — the skill's warning is stale, update section 4"
else ok "reset --hard destroys uncommitted work (known, documented)"; fi
if [ -n "$(git -C "$PRI" status --porcelain)" ]; then ok "reset --hard leaves the index dirty (known)"
else bad "reset --hard leaves the index dirty" "no longer reproduces; section 4 may be stale"; fi
allowed "git restore ... recovers (touches no refs)" -- restore --source=HEAD --staged --worktree .
# v3 refused this: a no-op ref still opens a transaction. v4's 'old = new' guard permits it, which
# is what lets the messages advise a command people already know.
echo TRANSIENT >> "$PRI/f1.txt"
allowed "git reset --hard HEAD recovers (v4: old = new)" -- reset --hard HEAD
if [ -z "$(git -C "$PRI" status --porcelain)" ]; then ok "reset --hard HEAD left the tree clean"
else bad "reset --hard HEAD left the tree clean" "still dirty: $(git -C "$PRI" status --porcelain)"; fi

g merge --no-ff probe/guardrail
if [ -f "$(gitdir "$PRI")/MERGE_HEAD" ]; then ok "refused merge leaves MERGE_HEAD (known)"
else bad "refused merge leaves MERGE_HEAD" "no longer reproduces; section 4 teardown may be stale"; fi
# v3 refused this — --abort ends in a reset to HEAD, a no-op transaction — and the primary stayed
# wedged mid-merge with only the core.hooksPath bypass on offer. That is the bug v4 started from.
allowed "git merge --abort clears a refused merge (v4)" -- merge --abort
if [ -z "$(git -C "$PRI" status --porcelain)" ] && [ ! -f "$(gitdir "$PRI")/MERGE_HEAD" ]; then
  ok "...and leaves no MERGE_HEAD and a clean tree"
else bad "...and leaves no MERGE_HEAD and a clean tree" "tree '$(git -C "$PRI" status --porcelain | tr '\n' ' ')'"; fi

# --- the load-bearing test: pull --ff-only must still fast-forward ------------------------------
head_ "pull --ff-only (the regression that matters)"
echo new > "$UP/f4.txt"; git -C "$UP" add -A; git -C "$UP" commit -qm c4
BEHIND=$(gs)
if git -C "$PRI" pull --ff-only >/dev/null 2>&1 && [ "$(gs)" != "$BEHIND" ]; then
  ok "pull --ff-only fast-forwards a primary that is BEHIND"
else bad "pull --ff-only fast-forwards a primary that is BEHIND" "main stuck at $BEHIND — the allowlist is broken"; fi

# Guard the guard: prove the test above is not vacuous. An allowlist-free hook must FAIL it.
cat > "$LAB/hooks/broken" <<'EOF'
#!/bin/sh
[ "$1" = prepared ] || exit 0
gd=$(cd "$(git rev-parse --git-dir)" && pwd); cm=$(cd "$(git rev-parse --git-common-dir)" && pwd)
[ "$gd" = "$cm" ] || exit 0
while read -r old new ref; do
  case "$ref" in refs/heads/*) ;; *) continue ;; esac
  [ "$old" = 0000000000000000000000000000000000000000 ] && continue
  echo "  BROKEN: refused every update to ${ref#refs/heads/}" >&2; exit 1
done
exit 0
EOF
chmod 755 "$LAB/hooks/broken"
git clone -q "$PRI" "$LAB/canary"
git -C "$LAB/canary" config user.email t@example.com; git -C "$LAB/canary" config user.name t
install_hooks "$LAB/canary" "$LAB/hooks/broken"
git -C "$LAB/canary" -c core.hooksPath=/dev/null reset --hard HEAD~2 >/dev/null 2>&1
CB=$(git -C "$LAB/canary" rev-parse main)
git -C "$LAB/canary" pull --ff-only >/dev/null 2>&1
if [ "$(git -C "$LAB/canary" rev-parse main)" = "$CB" ]; then
  ok "an allowlist-free hook FAILS that test (so it is not vacuous)"
else bad "an allowlist-free hook FAILS that test" "a hook refusing every ref update still fast-forwarded"; fi
# ...and the vacuity itself: same broken hook, but bring the canary CURRENT first (its pull above
# was refused, so it is still behind). An up-to-date pull fires no ref transaction, so the broken
# hook is never consulted and the test passes — which is precisely why section 7 needs a BEHIND clone.
git -C "$LAB/canary" -c core.hooksPath=/dev/null reset --hard origin/main >/dev/null 2>&1
if git -C "$LAB/canary" pull --ff-only >/dev/null 2>&1; then
  ok "up-to-date pull passes even with the broken hook (why section 7 needs a BEHIND clone)"
else bad "up-to-date pull passes with the broken hook" "expected a vacuous pass; the premise changed"; fi

# Guard the guard, again: strip ONLY the 'old = new' line from the real body and prove the stash
# test above fails. Without this, a future edit that drops the guard passes the suite if some other
# change happens to keep stash working.
head_ "The 'old = new' guard is load-bearing (v3 regression)"
grep -v '\[ "\$old" = "\$new" \]' "$LAB/hooks/reftxn" > "$LAB/hooks/noguard"; chmod 755 "$LAB/hooks/noguard"
if [ "$(wc -l < "$LAB/hooks/noguard")" -lt "$(wc -l < "$LAB/hooks/reftxn")" ]; then
  ok "the guard line was found and stripped for the canary"
else bad "the guard line was found and stripped for the canary" "grep matched nothing — the line was reworded, fix this pattern"; fi
git clone -q "$PRI" "$LAB/stash-canary"
git -C "$LAB/stash-canary" config user.email t@example.com; git -C "$LAB/stash-canary" config user.name t
install_hooks "$LAB/stash-canary" "$LAB/hooks/noguard"
echo scratch > "$LAB/stash-canary/gr.txt"; git -C "$LAB/stash-canary" add gr.txt
if git -C "$LAB/stash-canary" stash push -m canary >/dev/null 2>&1; then
  bad "a guard-free hook FAILS the stash test (so it is not vacuous)" "stash push exited 0 without the guard; the test proves nothing"
else ok "a guard-free hook FAILS the stash test (so it is not vacuous)"; fi
if [ "$(git -C "$LAB/stash-canary" stash list | wc -l | tr -d ' ')" = 1 ]; then
  ok "...and it stashed anyway — refused-but-effective, the v3 failure mode"
else bad "...and it stashed anyway — refused-but-effective" "no stash entry; the failure mode changed"; fi

# --- post-checkout: the one hook that warns instead of refusing ---------------------------------
# It cannot undo the switch, so its message is the entire remedy. v4 said only what was wrong.
# A branch switch reaches reference-transaction as a HEAD update, not a refs/heads/* one, so it is
# permitted — which is what makes `git switch main` safe to advise from inside the guardrail.
head_ "post-checkout warns on drift (section 3)"
warned() {  # warned <desc> <match ERE|-> -- <git args...>   : '-' means the warning must NOT appear
  local desc=$1 want=$2; shift 2; [ "$1" = -- ] && shift
  local before out; before=$(gs)
  out=$(git -C "$PRI" "$@" 2>&1 >/dev/null)
  if   [ "$(gs)" != "$before" ];                          then bad "$desc" "a branch switch moved main $before -> $(gs)"
  elif [ "$want" = - ]; then grep -q 'primary clone is on' <<<"$out" \
         && bad "$desc" "warned when parked correctly: $(tr '\n' '|' <<<"$out")" || ok "$desc"
  elif grep -Eq "$want" <<<"$out";                        then ok "$desc"
  else bad "$desc" "message lacks /$want/ — got: $(tr '\n' '|' <<<"$out")"; fi
}
warned "drifting the primary warns"            "primary clone is on 'drift/probe', not main" -- switch -c drift/probe
warned "...and the warning carries the fix (v5)" 'git switch main'                           -- switch -c drift/probe2
warned "switching back to main is silent"      -                                             -- switch main
git -C "$PRI" branch -qD drift/probe drift/probe2

# --- the SessionStart hook: the same fact, restated when it next matters ------------------------
# post-checkout fires once, into a terminal that scrolls. This runs at session start, from wherever
# the session opened, and its stdout is added to the agent's context.
head_ "SessionStart drift check (section 9)"
DC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/session-drift-check.sh"
[ -x "$DC" ] || { echo "missing or non-executable: $DC" >&2; exit 1; }

drift_says() {  # drift_says <desc> <dir> <match ERE|->   : '-' means it must print NOTHING
  local desc=$1 dir=$2 want=$3 out rc
  out=$(cd "$dir" 2>/dev/null && "$DC" 2>/dev/null); rc=$?
  if   [ "$rc" != 0 ];   then bad "$desc" "exit $rc — a SessionStart hook that exits non-zero logs a failure every session"
  elif [ "$want" = - ];  then [ -z "$out" ] && ok "$desc" || bad "$desc" "expected silence, got: $(tr '\n' '|' <<<"$out")"
  elif grep -Eq "$want" <<<"$out"; then ok "$desc"
  else bad "$desc" "message lacks /$want/ — got: $(tr '\n' '|' <<<"$out")"; fi
}

# Premise for the not-a-repo case below: the lab must not itself sit inside a repository.
if (cd "$LAB" && git rev-parse --git-common-dir >/dev/null 2>&1); then
  bad "the lab dir is not inside a git repo (premise)" "TMPDIR is inside a repo; the not-a-repo case cannot be tested here"
else ok "the lab dir is not inside a git repo (premise)"; fi

mkdir -p "$PRI/sub2"
drift_says "silent when the primary is parked (from the primary)"  "$PRI"      -
drift_says "silent when parked (from a subdirectory of it)"        "$PRI/sub2" -
drift_says "silent when parked (from a linked worktree)"           "$WT"       -
drift_says "silent outside any repo (dirname of a failed rev-parse would give /)" "$LAB" -

# The reported path is asserted by PROPERTY, not by string. The same primary resolves to
# /var/folders/... from inside itself and /private/var/folders/... from a worktree, because git
# records the real path in the worktree's .git file and macOS symlinks /var. Both are valid and
# `git -C` accepts either, so what has to hold is that the path names a primary clone at all.
fix_targets_a_primary() {  # <desc> <dir>
  local desc=$1 dir=$2 out p gd cm
  out=$(cd "$dir" && "$DC" 2>/dev/null)
  p=$(sed -n 's/.*Fix:  git -C \(.*\) switch .*/\1/p' <<<"$out")
  if [ -z "$p" ] || [ ! -d "$p" ]; then bad "$desc" "no usable path in: $(tr '\n' '|' <<<"$out")"; return; fi
  gd=$(cd "$p" && cd "$(git rev-parse --git-dir)" && pwd -P)
  cm=$(cd "$p" && cd "$(git rev-parse --git-common-dir)" && pwd -P)
  if [ "$gd" = "$cm" ]; then ok "$desc"
  else bad "$desc" "'$p' is a linked worktree, not the primary ($gd != $cm)"; fi
}

git -C "$PRI" switch -q -c drift/session 2>/dev/null
drift_says "drift reported from the primary"  "$PRI"      "is on 'drift/session', not 'main'"
drift_says "...and from a subdirectory of it" "$PRI/sub2" "is on 'drift/session', not 'main'"
# This is the case post-checkout cannot cover at all: the agent is working in a worktree and never
# ran the switch, so it never saw the warning.
drift_says "...and from a linked worktree, which never saw post-checkout" "$WT" "is on 'drift/session', not 'main'"
drift_says "the report carries the fix"       "$WT"       "Fix:  git -C .* switch main\$"
fix_targets_a_primary "the fix points at the primary clone, not the worktree it was run from" "$WT"
fix_targets_a_primary "...and at the same clone when run from inside it"                      "$PRI"

# symbolic-ref FAILS on a detached HEAD rather than returning something, so the obvious form leaves
# the variable empty and reports nothing. `git switch --detach` is a drift path section 2 exists for.
git -C "$PRI" switch -q --detach main 2>/dev/null
drift_says "a detached primary is reported, not silently skipped" "$WT" "is on 'detached HEAD'"
git -C "$PRI" switch -q main 2>/dev/null
git -C "$PRI" branch -qD drift/session; rmdir "$PRI/sub2"
drift_says "back to parked: silent again" "$WT" -

# Hardcoding 'main' would warn every session about a correctly-parked clone. Measured across 19
# local repos, one parks on 'Dev'. origin/HEAD is the authority; 'main' is only the fallback.
mkdir -p "$LAB/updev" && git -C "$LAB/updev" init -q -b Dev .
git -C "$LAB/updev" config user.email t@example.com; git -C "$LAB/updev" config user.name t
echo d > "$LAB/updev/d.txt"; git -C "$LAB/updev" add -A; git -C "$LAB/updev" commit -qm d1
git clone -q "$LAB/updev" "$LAB/devclone"
if [ "$(git -C "$LAB/devclone" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" = origin/Dev ]; then
  ok "git clone sets origin/HEAD (the premise the default-branch lookup rests on)"
else bad "git clone sets origin/HEAD" "unset or wrong; the script would fall back to 'main' and misfire"; fi
drift_says "a repo parked on 'Dev' is silent, not warned at"      "$LAB/devclone" -
git -C "$LAB/devclone" switch -q -c feature 2>/dev/null
drift_says "...and its drift names 'Dev', not 'main'"             "$LAB/devclone" "not 'Dev'"
drift_says "...and its fix switches to 'Dev'"                     "$LAB/devclone" "switch Dev\$"

# --- the hooks-path resolution bug the installer snippets have to avoid -------------------------
head_ "Hooks-path resolution (sections 5 and 6)"
mkdir -p "$PRI/sub"
REL=$(cd "$PRI/sub" && git rev-parse --git-common-dir)
case "$REL" in
  /*) bad "--git-common-dir is relative in the primary" "returned absolute '$REL'; the cd/pwd guidance may be stale" ;;
  *)  ok "--git-common-dir is relative in the primary ('$REL' from a subdir)" ;;
esac
ABS=$(cd "$PRI/sub" && cd "$(git rev-parse --git-common-dir)" && pwd)
if [ -x "$ABS/hooks/pre-commit" ]; then ok "cd/pwd resolution finds the hooks from a subdir"
else bad "cd/pwd resolution finds the hooks from a subdir" "resolved to $ABS"; fi
rmdir "$PRI/sub"

head_ "Invariant"
if [ "$(gs)" = "$BEHIND" ] || [ "$(gs)" = "$(git -C "$UP" rev-parse main)" ]; then
  ok "main only ever moved by pull --ff-only (now $(git -C "$PRI" rev-parse --short main), started $(git -C "$PRI" rev-parse --short "$BASE"))"
else bad "main only ever moved by pull --ff-only" "unexpected sha $(gs)"; fi

printf '\n\033[1m%d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then printf '  %s\n' "${FAILED[@]}"; exit 1; fi
