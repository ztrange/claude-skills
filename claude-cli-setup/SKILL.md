---
name: claude-cli-setup
description: >-
  Make Claude Code run exactly as it does here — copy-code mod, status line, custom theme,
  keybindings and the settings.json keys that wire them. Reached with `/dev-tools claude-cli`.
disable-model-invocation: true
---

# Claude CLI setup — once per machine

Claude Code must already be installed. Run `scripts/install.sh`; it is idempotent and prints one
line per item. Relay the `backup` / `wrote` lines and the restart reminder.

| Installs | From | To |
|---|---|---|
| `copy-code` mod: a Copy button under each code block in a reply | `files/mods/copy-code/` | `~/mods/copy-code/` |
| Status line: model/effort, context + compact budget, 5h/weekly limits, account, `/rc` marker | `files/statusline-command.sh` | `~/.claude/statusline-command.sh` |
| `custom:mine` theme (dark, rose user-message background) | `files/themes/mine.json` | `~/.claude/themes/mine.json` |
| `cmd+z` → undo in the prompt | `files/keybindings.json` | `~/.claude/keybindings.json` |
| Settings keys | `files/settings.fragment.json` | deep-merged into `~/.claude/settings.json` |

Settings keys merged: `env.CLAUDE_CODE_PLUGIN_DIRS` (loads the mod), `statusLine`, `theme`,
`tui: fullscreen`, `timeFormat`, `model: opus` + per-model `effortLevel` / `autoCompactWindow`
(the status line reads the latter), `remoteControlAtStartup`, `agentPushNotifEnabled`,
`awaySummaryEnabled: false`, `idleCompaction`, `permissions.allow` (unioned, never replaced), and
**`skipDangerousModePermissionPrompt: true`** — say that one out loud before running, it removes a
safety prompt. Every other key in the user's settings is left alone; `autoMode` is deliberately
not carried (it describes one project, not the machine).

- Replaced files are kept as `<file>.bak-<timestamp>`. Installs `jq` via Homebrew if missing —
  the status line needs it.
- The mod's `.claude-plugin/types/` is not carried: it is editor typecheck output under its own
  `*` gitignore, rewritten after the sources were last edited (so not authored by us), and
  `hooks.json` loads only `register.tsx`.
- Kitty's Claude-specific keys (image paste, clear input) belong to `/dev-tools kitty`.

## Changing it

`files/` is the source of truth; the targets are installed copies. Edit here, re-run, restart
Claude Code.
