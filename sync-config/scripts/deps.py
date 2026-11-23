#!/usr/bin/env python3
"""List what each installed skill depends on that the symlinks don't show.

For every skill linked under ~/.claude/skills/, scans its *.md files for:
  - other skills it invokes: quoted names on a "Skill tool" line, and `/name` slash references
    to a skill that exists somewhere under ~/Documents/repos;
  - repos it reads by absolute path (~/Documents/repos/<org>/<repo>/...), outside its own repo.

Prints one line per skill with dependencies, then the repos to add to the fetch list.
A dependency that is not linked is marked NOT LINKED; one that exists in no repo, NOT FOUND. Read-only: links nothing, pulls nothing.
"""
import os
import re
import subprocess
from pathlib import Path

HOME = Path.home()
SKILLS = HOME / ".claude" / "skills"
REPOS = HOME / "Documents" / "repos"
NAME = re.compile(r"^name:\s*([a-z0-9-]+)\s*$", re.M)
SKILL_TOOL_LINE = re.compile(r"^.*Skill tool.*$", re.M)
QUOTED = re.compile(r'"([a-z0-9][a-z0-9-]*)"')
SLASH = re.compile(r"(?<![\w./~>-])/([a-z0-9][a-z0-9-]*)(?![\w/-])")
ABS_PATH = re.compile(r"(?:~|/Users/[^/\s]+)/Documents/repos/([\w.-]+)/([\w.-]+)")


def toplevel(path):
    r = subprocess.run(["git", "-C", str(path), "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def known_skills():
    """Every skill name that exists in a repo checkout, linked or not."""
    names = {}
    for root, dirs, files in os.walk(REPOS):
        depth = len(Path(root).relative_to(REPOS).parts)
        dirs[:] = [d for d in dirs if d not in ("node_modules", ".git", "deprecated", "worktrees")
                   and depth < 5]
        if "SKILL.md" in files:
            m = NAME.search((Path(root) / "SKILL.md").read_text(errors="ignore"))
            if m:
                names.setdefault(m.group(1), set()).add(toplevel(root))
    return names


def main():
    linked = {p.name: p for p in SKILLS.iterdir() if (p / "SKILL.md").exists()}
    where = known_skills()  # name -> repos holding it
    known = set(where) | set(linked)
    fetch = {}
    for name in sorted(linked):
        target = linked[name].resolve()
        own = toplevel(target)
        needs, reads = set(), set()
        for md in target.rglob("*.md"):
            text = md.read_text(errors="ignore")
            for line in SKILL_TOOL_LINE.findall(text):
                needs |= set(QUOTED.findall(line))  # a Skill tool call names a skill, found or not
            needs |= {s for s in SLASH.findall(text) if s in known}
            for org, repo in ABS_PATH.findall(text):
                top = toplevel(REPOS / org / repo)
                if top is None:
                    reads.add(str(REPOS / org / repo) + " (MISSING)")
                elif top != own:
                    reads.add(top)
        needs.discard(name)
        # A skill read by path from a repo already listed under "reads" is that read, not a link.
        needs = {d for d in needs if d in linked or not (where.get(d, set()) & reads)}
        if not (needs or reads):
            continue
        parts = [d if d in linked else f"{d} (NOT LINKED)" if d in known else f"{d} (NOT FOUND)"
                 for d in sorted(needs)]
        parts += [f"reads {Path(r).relative_to(REPOS)}" for r in sorted(reads)]
        print(f"{name} -> {', '.join(parts)}")
        for r in reads:
            if not r.endswith("(MISSING)"):
                fetch.setdefault(r, []).append(name)
    for repo, users in sorted(fetch.items()):
        print(f"fetch: {repo}  (read by {', '.join(users)})")


if __name__ == "__main__":
    main()
