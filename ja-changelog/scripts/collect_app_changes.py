#!/usr/bin/env python3
"""
Collect the raw material needed to write a changelog for one Jalisco Alerta app.

Why this exists: turning git tags into "what shipped in each release" is fiddly for
these repos because they create many *draft* releases (one per PR) interleaved with
the real *published* releases. A published release therefore usually bundles several
draft-tagged commits. To see everything that shipped in a published release you must
diff the *previous published (non-draft) tag* -> *this published tag*, NOT just look at
the release body (which is often empty or only lists one PR).

This script does exactly that, deterministically, so the model can focus on
interpretation instead of re-deriving compare ranges (and getting them wrong).

Output: JSON to stdout. One object with the repo, the resolved scope, and a list of
releases (newest first), each with its commits, merged PRs, and changed files.

Usage:
    python3 collect_app_changes.py <repo_path> [--since vX.Y.Z] [--max 50]

  --since   Only include published releases strictly newer than this tag.
            Omit to include every published release (full backfill).
  --max     Safety cap on how many releases to emit (default 50).

Requires: git, and the `gh` CLI authenticated for the repo's GitHub org.
"""
import argparse
import json
import re
import subprocess
import sys


def run(cmd, cwd=None):
    res = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"command failed: {' '.join(cmd)}\n{res.stderr.strip()}")
    return res.stdout


def parse_version(tag):
    """Return a sortable tuple from a tag like v2.269.0 -> (2,269,0). Non-semver sorts last."""
    m = re.search(r"(\d+)\.(\d+)\.(\d+)", tag or "")
    if not m:
        return (-1, -1, -1)
    return tuple(int(x) for x in m.groups())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo_path")
    ap.add_argument("--since", default=None)
    ap.add_argument("--max", type=int, default=50)
    args = ap.parse_args()
    repo = args.repo_path

    # Make sure local tags/refs are current. Non-fatal if offline.
    try:
        run(["git", "fetch", "--tags", "--quiet"], cwd=repo)
    except RuntimeError as e:
        print(f"warning: git fetch failed: {e}", file=sys.stderr)

    # All releases from GitHub, with draft/prerelease flags.
    raw = run(["gh", "release", "list", "--limit", "300",
               "--json", "tagName,name,isDraft,isPrerelease,publishedAt"], cwd=repo)
    releases = json.loads(raw)

    # Keep only real releases the client actually received.
    published = [r for r in releases if not r["isDraft"] and not r["isPrerelease"]]
    published.sort(key=lambda r: parse_version(r["tagName"]))  # ascending

    since_v = parse_version(args.since) if args.since else None

    out_releases = []
    for idx, rel in enumerate(published):
        tag = rel["tagName"]
        if since_v is not None and parse_version(tag) <= since_v:
            continue
        prev_tag = published[idx - 1]["tagName"] if idx > 0 else None
        rng = f"{prev_tag}..{tag}" if prev_tag else tag

        # Commits (excluding merge commits — the PR title/body carries the meaning).
        log_fmt = "%H%x1f%s%x1f%an%x1e"
        commits_raw = run(["git", "log", rng, "--no-merges", f"--pretty=format:{log_fmt}"], cwd=repo)
        commits = []
        for rec in commits_raw.split("\x1e"):
            rec = rec.strip()
            if not rec:
                continue
            h, subject, author = (rec.split("\x1f") + ["", "", ""])[:3]
            commits.append({"hash": h[:9], "subject": subject, "author": author})

        # Merged PRs in this range — these map most cleanly to ClickUp tasks.
        merges_raw = run(["git", "log", rng, "--merges", "--pretty=format:%s%x1f%b%x1e"], cwd=repo)
        prs = []
        for rec in merges_raw.split("\x1e"):
            rec = rec.strip()
            if not rec:
                continue
            subject = rec.split("\x1f")[0]
            m = re.search(r"#(\d+)\s+from\s+\S+/(\S+)", subject)
            num = int(m.group(1)) if m else None
            branch = m.group(2) if m else None
            # The PR's human title is the line after the merge subject in the body.
            body = rec.split("\x1f")[1] if "\x1f" in rec else ""
            title = next((ln.strip() for ln in body.splitlines() if ln.strip()), "")
            prs.append({"number": num, "branch": branch, "title": title})

        # Changed files (names only) so the model can sense scope/area.
        files_raw = run(["git", "diff", "--name-only", rng], cwd=repo) if prev_tag else ""
        files = [f for f in files_raw.splitlines() if f.strip()]

        out_releases.append({
            "tag": tag,
            "name": rel.get("name") or tag,
            "publishedAt": rel.get("publishedAt"),
            "compareRange": rng,
            "prs": prs,
            "commits": commits,
            "changedFiles": files,
        })

    out_releases.sort(key=lambda r: parse_version(r["tag"]), reverse=True)  # newest first
    out_releases = out_releases[: args.max]

    print(json.dumps({
        "repoPath": repo,
        "since": args.since,
        "publishedReleaseCount": len(published),
        "latestPublished": published[-1]["tagName"] if published else None,
        "releasesInScope": len(out_releases),
        "releases": out_releases,
    }, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
