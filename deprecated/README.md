# deprecated

Skills that have moved elsewhere. Kept for history; not installed.

- **ja-changelog** — moved into its product repo at `erliamx/ja-changelog` under `skill/`
  (2026-07-23). It's co-located with the app it feeds (DynamoDB + API + site), which removes the
  cross-repo coupling between the skill and the `write_release.py` / `latest_version.py` CLIs it
  calls. Installed point-in-place: `~/.claude/skills/ja-changelog` symlinks to
  `…/erlia/ja-changelog/skill`. This copy is a frozen snapshot — do not edit it.
