# deprecated

Skills that have moved elsewhere. Kept for history; not installed.

- **ja-changelog** — moved into its product repo at `erliamx/ja-changelog` under `skill/`
  (2026-07-23). It's co-located with the app it feeds (DynamoDB + API + site), which removes the
  cross-repo coupling between the skill and the `write_release.py` / `latest_version.py` CLIs it
  calls. It installs with that repo too: `erliamx/ja-changelog` tracks
  `.claude/skills/ja-changelog -> ../../skill`, so there is nothing to link under `~/.claude/`
  (2026-08-13). This copy is a frozen snapshot — do not edit it.

- **sitrep** — folded into [`wrap-up`](../wrap-up/SKILL.md) (2026-10-18). Its two load-bearing
  rules moved there: observe the tree rather than recall it (step 1), and keep the closing report
  very succinct (`## Report`). The three-section format it defined — Done / Remaining / Needs you —
  was also mandated for every work turn by `user-prompt/CLAUDE.md`; that mandate is gone, and no
  format is imposed globally any more. A project that wants a structured status report defines its
  own sections, which is what `veri` does in `specs/utility-skills.md` (PRD 011, section A:
  Landed / Running / Queue / Waiting). Last invoked 2026-09-13, twelve days after the global rule
  made it redundant, after 40 invocations. This copy is a frozen snapshot — do not edit it.
