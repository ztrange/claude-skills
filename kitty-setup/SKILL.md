---
name: kitty-setup
description: >-
  Install kitty on a Mac exactly as configured here — app, Nerd Font, kitty.conf, Dracula theme
  and the zsh `claude()` wrapper its Claude Code key maps need. Reached with `/dev-tools kitty`.
disable-model-invocation: true
---

# Kitty setup — once per Mac

Run `scripts/install.sh`. It is idempotent and prints one line per item (`ok` / `added` /
`backup` / `wrote`); relay the `backup` and `wrote` lines, not the `ok` ones.

| Installs | From | To |
|---|---|---|
| kitty, JetBrainsMono Nerd Font | Homebrew casks | `/Applications`, `~/Library/Fonts` |
| Config — only our changes from kitty's defaults, each with why | `files/kitty.conf` | `~/.config/kitty/kitty.conf` |
| Dracula colours (the `include` in kitty.conf) | `files/current-theme.conf` | `~/.config/kitty/current-theme.conf` |
| `claude()` wrapper setting kitty's `in_claude` user var | `files/claude-kitty.zsh` | appended to `~/.zshrc` |

- An existing file that differs is kept as `<file>.bak-<timestamp>` before it is replaced — never
  delete those for the user.
- The wrapper is the dependency that's easy to miss: without it the `cmd+v` image paste and
  `cmd+backspace` clear-input maps never fire, because both are scoped to `var:in_claude`. It is
  skipped when `~/.zshrc` already sets that var.
- macOS only; needs Homebrew. Running kitty windows reload on the script's `SIGUSR1`; the wrapper
  takes a new shell.
- Claude Code's own config (mods, status line, theme, settings) is the separate
  `/dev-tools claude-cli`.

## Changing the config

`files/` is the source of truth; `~/.config/kitty/` is an installed copy (kitty's theme kitten
rewrites `kitty.conf` in place, which would dirty the repo through a symlink). Edit here, re-run
the installer. Every line carries a comment saying why it was added — keep it that way, and add
nothing that only restates a kitty default.
