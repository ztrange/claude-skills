# deprecated

Skills that have moved elsewhere. Kept for history; not installed.

- **ja-changelog** — moved into its product repo at `erliamx/ja-changelog` under `skill/`
  (2026-07-23). It's co-located with the app it feeds (DynamoDB + API + site), which removes the
  cross-repo coupling between the skill and the `write_release.py` / `latest_version.py` CLIs it
  calls. It installs with that repo too: `erliamx/ja-changelog` tracks
  `.claude/skills/ja-changelog -> ../../skill`, so there is nothing to link under `~/.claude/`
  (2026-08-13). This copy is a frozen snapshot — do not edit it.
