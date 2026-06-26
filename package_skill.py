#!/usr/bin/env python3
"""Standalone packager (no PyYAML): validate minimal frontmatter, then zip to .skill."""
import fnmatch
import re
import sys
import zipfile
from pathlib import Path

skill_path = Path(sys.argv[1]).resolve()
output_dir = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else skill_path.parent

EXCLUDE_DIRS = {"__pycache__", "node_modules"}
EXCLUDE_GLOBS = {"*.pyc"}
EXCLUDE_FILES = {".DS_Store"}
ROOT_EXCLUDE_DIRS = {"evals"}


def should_exclude(rel_path: Path) -> bool:
    parts = rel_path.parts
    if any(p in EXCLUDE_DIRS for p in parts):
        return True
    if len(parts) > 1 and parts[1] in ROOT_EXCLUDE_DIRS:
        return True
    if rel_path.name in EXCLUDE_FILES:
        return True
    return any(fnmatch.fnmatch(rel_path.name, pat) for pat in EXCLUDE_GLOBS)


# --- minimal validation: frontmatter must have name + description ---
md = (skill_path / "SKILL.md").read_text(encoding="utf-8")
m = re.match(r"^---\s*\n(.*?)\n---\s*\n", md, re.DOTALL)
if not m:
    print("❌ SKILL.md has no YAML frontmatter block")
    sys.exit(1)
fm = m.group(1)
has_name = re.search(r"^name:\s*\S+", fm, re.MULTILINE)
has_desc = re.search(r"^description:\s*", fm, re.MULTILINE)
if not has_name or not has_desc:
    print("❌ frontmatter missing name or description")
    sys.exit(1)
name_val = re.search(r"^name:\s*(\S+)", fm, re.MULTILINE).group(1)
print(f"✅ Validation passed (name: {name_val})\n")

output_dir.mkdir(parents=True, exist_ok=True)
skill_file = output_dir / f"{skill_path.name}.skill"

with zipfile.ZipFile(skill_file, "w", zipfile.ZIP_DEFLATED) as zf:
    for fp in sorted(skill_path.rglob("*")):
        if not fp.is_file():
            continue
        arc = fp.relative_to(skill_path.parent)
        if should_exclude(arc):
            print(f"  Skipped: {arc}")
            continue
        zf.write(fp, arc)
        print(f"  Added:   {arc}")

print(f"\n✅ Packaged to: {skill_file}")
