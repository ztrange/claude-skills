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
    python3 collect_app_changes.py <repo_path> --preview [--since vX.Y.Z] [--head REF]

  --since   Only include published releases strictly newer than this tag.
            Omit to include every published release (full backfill).
            In --preview mode, overrides the baseline tag (default: latest published).
  --max     Safety cap on how many releases to emit (default 50).
  --preview Simulate releasing the tip of the default branch: emit ONE pseudo-release
            diffing the latest published tag (or --since) -> HEAD. This captures the
            merged-but-unreleased backlog ("what would ship if we cut a release now").
            Fetch/pull first so the tip is current.
  --head    Ref to treat as the tip in --preview mode. Default: auto-detect origin/HEAD
            (e.g. origin/main), falling back to local HEAD.

Requires: git, and the `gh` CLI authenticated for the repo's GitHub org.
"""
import argparse
import json
import os
import re
import subprocess
import sys

# Never block on a credential/passphrase prompt — a missing-auth fetch should fail fast,
# not hang the whole run (git fetch below is non-fatal anyway).
os.environ.setdefault("GIT_TERMINAL_PROMPT", "0")
os.environ.setdefault("GIT_SSH_COMMAND", "ssh -o BatchMode=yes")


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


def detect_head(repo):
    """Best-effort default-branch tip for --preview: origin/HEAD (e.g. origin/main), else HEAD."""
    try:
        ref = run(["git", "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"], cwd=repo).strip()
        if ref:  # refs/remotes/origin/main -> origin/main
            return ref.replace("refs/remotes/", "")
    except RuntimeError:
        pass
    return "HEAD"


def collect_range(repo, rng, has_prev):
    """Extract commits, merged PRs, and changed files for a git range 'a..b' (or a single ref)."""
    log_fmt = "%H%x1f%s%x1f%an%x1e"
    commits_raw = run(["git", "log", rng, "--no-merges", f"--pretty=format:{log_fmt}"], cwd=repo)
    commits = []
    for rec in commits_raw.split("\x1e"):
        rec = rec.strip()
        if not rec:
            continue
        h, subject, author = (rec.split("\x1f") + ["", "", ""])[:3]
        commits.append({"hash": h[:9], "subject": subject, "author": author})

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
        body = rec.split("\x1f")[1] if "\x1f" in rec else ""
        title = next((ln.strip() for ln in body.splitlines() if ln.strip()), "")
        prs.append({"number": num, "branch": branch, "title": title})

    files_raw = run(["git", "diff", "--name-only", rng], cwd=repo) if has_prev else ""
    files = [f for f in files_raw.splitlines() if f.strip()]
    return commits, prs, files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo_path")
    ap.add_argument("--since", default=None)
    ap.add_argument("--max", type=int, default=50)
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--head", default=None)
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
    latest_published = published[-1]["tagName"] if published else None

    # --preview: one pseudo-release from the latest published tag (or --since) -> default-branch tip.
    if args.preview:
        baseline = args.since or latest_published
        head = args.head or detect_head(repo)
        rng = f"{baseline}..{head}" if baseline else head
        try:
            head_sha = run(["git", "rev-parse", "--short", head], cwd=repo).strip()
        except RuntimeError:
            head_sha = None
        commits, prs, files = collect_range(repo, rng, has_prev=bool(baseline))
        preview_entry = {
            "tag": f"{head} (preview)",
            "name": f"preview desde {baseline}" if baseline else "preview",
            "publishedAt": None,
            "headRef": head,
            "headSha": head_sha,
            "compareRange": rng,
            "prs": prs,
            "commits": commits,
            "changedFiles": files,
        }
        print(json.dumps({
            "repoPath": repo,
            "mode": "preview",
            "baseline": baseline,
            "head": head,
            "publishedReleaseCount": len(published),
            "latestPublished": latest_published,
            "unreleasedCommitCount": len(commits),
            "releases": [preview_entry],
        }, indent=2, ensure_ascii=False))
        return

    since_v = parse_version(args.since) if args.since else None

    out_releases = []
    for idx, rel in enumerate(published):
        tag = rel["tagName"]
        if since_v is not None and parse_version(tag) <= since_v:
            continue
        prev_tag = published[idx - 1]["tagName"] if idx > 0 else None
        rng = f"{prev_tag}..{tag}" if prev_tag else tag

        commits, prs, files = collect_range(repo, rng, has_prev=bool(prev_tag))

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
        "latestPublished": latest_published,
        "releasesInScope": len(out_releases),
        "releases": out_releases,
    }, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
