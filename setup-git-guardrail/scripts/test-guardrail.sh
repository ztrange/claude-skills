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

head_ "Refused in the primary clone (section 4 table)"
refused "git commit"                         -- commit --allow-empty -m probe
refused "git commit --no-verify"             -- commit --allow-empty --no-verify -m probe
refused "git commit --amend"                 -- commit --amend --no-edit
refused "git merge --no-ff"                  -- merge --no-ff probe/guardrail
g merge --quit
refused "git cherry-pick"                    -- cherry-pick "$PROBE"
g cherry-pick --quit
refused "git revert"                         -- revert --no-edit HEAD
refused "git reset --hard"                   -- reset --hard HEAD~1
g restore --source=HEAD --staged --worktree .
git -C "$PRI" merge --squash probe/guardrail >/dev/null 2>&1
refused "git merge --squash + commit"        -- commit -m probe
g merge --quit; g restore --source=HEAD --staged --worktree .; rm -f "$PRI/f4.txt"

# --- documented sharp edges: assert them, so a git change that fixes them shows up here ---------
head_ "Documented sharp edges (section 4: refused != no-op)"
echo "PRECIOUS" >> "$PRI/f1.txt"
g reset --hard HEAD~1
if grep -q PRECIOUS "$PRI/f1.txt" 2>/dev/null; then
  bad "reset --hard destroys uncommitted work" "it no longer does — the skill's warning is stale, update section 4"
else ok "reset --hard destroys uncommitted work (known, documented)"; fi
if [ -n "$(git -C "$PRI" status --porcelain)" ]; then ok "reset --hard leaves the index dirty (known)"
else bad "reset --hard leaves the index dirty" "no longer reproduces; section 4 may be stale"; fi
if g reset --hard HEAD; then bad "git reset --hard HEAD is refused" "it succeeded; the documented recovery advice is now wrong"
else ok "git reset --hard HEAD is itself refused (no-op ref still transacts)"; fi
allowed "git restore ... recovers (touches no refs)" -- restore --source=HEAD --staged --worktree .

g merge --no-ff probe/guardrail
if [ -f "$(gitdir "$PRI")/MERGE_HEAD" ]; then ok "refused merge leaves MERGE_HEAD (known)"
else bad "refused merge leaves MERGE_HEAD" "no longer reproduces; section 4 teardown may be stale"; fi
if g merge --abort; then bad "git merge --abort is refused" "it succeeded; --quit guidance can be relaxed"
else ok "git merge --abort is itself refused (known)"; fi
allowed "git merge --quit clears the state"          -- merge --quit
g restore --source=HEAD --staged --worktree .

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
