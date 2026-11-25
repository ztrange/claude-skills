#!/bin/sh
# Open a GitHub pull request in kitten diff, side by side.
#   pr-diff.sh https://github.com/OWNER/REPO/pull/N
#   pr-diff.sh '#N'          (resolved against the GitHub repo of the current directory)
# Files come from the GitHub API at the PR's merge base and head, so any repo gh can read works,
# cloned here or not, and no local clone is fetched into or checked out.
# kitty's ctrl+shift+p>d hint map calls this with whatever PR reference was picked on screen.
set -eu
# kitty launches this without the login shell's PATH, so Homebrew's gh would not be found.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

fail() { echo "pr-diff: $*" >&2; [ -t 0 ] && { printf 'Press Enter to close.'; read -r _; }; exit 1; }

ref=${1:-}
case $ref in
  *github.com/*/pull/[0-9]*)
    repo=$(printf %s "$ref" | sed -E 's#.*github\.com/([^/]+/[^/]+)/pull/.*#\1#')
    n=$(printf %s "$ref" | sed -E 's#.*/pull/([0-9]+).*#\1#') ;;
  \#[0-9]*)
    n=${ref#\#}
    command -v gh >/dev/null || fail "gh not found on PATH ($PATH)"
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>&1) \
      || fail "#$n: no GitHub repo for $(pwd): $repo" ;;
  *) fail "not a PR reference: '$ref' (want a github.com/…/pull/N URL or #N)" ;;
esac

pr=$(gh api "repos/$repo/pulls/$n" -q '[.base.sha, .head.sha] | @tsv' 2>&1) \
  || fail "$repo#$n: $pr"
base_tip=${pr%%	*} head=${pr##*	}
# GitHub diffs a PR against the merge base, not the base branch tip; match it.
base=$(gh api "repos/$repo/compare/$base_tip...$head" -q .merge_base_commit.sha) \
  || fail "$repo#$n: cannot resolve the merge base"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/pr-diff.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
a="$tmp/base" b="$tmp/pr$n"
mkdir -p "$a" "$b"

gh api --paginate "repos/$repo/pulls/$n/files" \
  -q '.[] | [.status, .filename, (.previous_filename // .filename)] | @tsv' > "$tmp/files"
[ -s "$tmp/files" ] || fail "$repo#$n changes no files"

fetch() { # sha path dest
  mkdir -p "$(dirname "$3")"
  gh api -H 'Accept: application/vnd.github.raw' \
    "repos/$repo/contents/$(printf %s "$2" | sed 's/ /%20/g')?ref=$1" > "$3"
}
echo "$repo#$n: fetching $(wc -l < "$tmp/files" | tr -d ' ') files…"
tab=$(printf '\t')
while IFS=$tab read -r status file prev; do
  [ "$status" = added ]   || fetch "$base" "$prev" "$a/$prev"
  [ "$status" = removed ] || fetch "$head" "$file" "$b/$file"
done < "$tmp/files"

kitten diff "$a" "$b"
