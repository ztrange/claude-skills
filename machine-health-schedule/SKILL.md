---
name: machine-health-schedule
description: >-
  Install or uninstall the unattended side of machine-health on this Mac: a per-user LaunchAgent
  that checks every 30 min and kills leaked Claude Bash shells, and a root LaunchDaemon that
  restarts a pegged fseventsd. Reached with `/dev-tools machine-health`.
disable-model-invocation: true
---

# Machine-health schedule — install once, uninstall on request

Once per machine. Ask which of the two the user wants (default: both), and whether it is install
or uninstall — "remove", "turn off", "stop the watchdog" all mean uninstall. Both cost $0: no
model runs, ~1 s of CPU per check.

| Piece | Runs as | Every | Does unattended | Log |
|---|---|---|---|---|
| Agent `com.user.machine-health` | the user | 30 min | `snapshot.py --fix`: kills leaked Claude Bash shells (PPID 1, from `.claude/shell-snapshots/`, > 10 min). Notifies on any remaining WARN/CRIT; kills nothing else | `~/Library/Logs/machine-health/` — `latest.txt`, `fixed.log`, `last-run` |
| Daemon `com.user.machine-health.fseventsd` | root | 2 min | `fseventsd` ≥ 80% on 2 consecutive 3 s samples → `killall`, then `killall -9` if the pid survives 10 s; then 15 min cooldown, so a storm that persists logs instead of looping | `/var/log/machine-health-fseventsd.log` |

Both pieces run **installed copies**, never the repo: the agent from `~/Library/Application
Support/machine-health/`, the daemon from `/usr/local/libexec/machine-health/`. The installers copy
from the main clone, so machine-health must be merged and pulled first. Why copies: macOS privacy
protection (TCC) blocks launchd jobs from `~/Documents` — the agent pointed at the repo failed with
exit 126, "Operation not permitted" — and a root job must not run a user-writable file.
Consequence for both: **a change to `snapshot.py`, `scheduled-check.sh` or
`fseventsd-watchdog.sh` is live only after re-running its installer** — say so whenever one changes.
Don't "fix" exit 126 by granting `/bin/sh` Full Disk Access: that opens every protected folder to
every shell script.

## Agent — you run it

```bash
sh <this skill>/scripts/install-agent.sh              # install or refresh
sh <this skill>/scripts/install-agent.sh --uninstall
```

Verify an install by running it once now rather than waiting 30 min:

```bash
launchctl kickstart -k gui/$(id -u)/com.user.machine-health && sleep 10 && ls -l ~/Library/Logs/machine-health/
```

`last-run` with the current time and `last exit code = 0` in `launchctl print
gui/$(id -u)/com.user.machine-health` = it ran. Exit 126 = it is pointed at a TCC-protected path. Uninstall is verified by the script itself (it fails if
the label is still loaded).

## Daemon — the user runs it

It needs root, which you don't have. Hand over the command with the absolute path to this skill's
`scripts/` in the **main clone**, never a worktree:

```bash
sudo sh <main clone>/machine-health-schedule/scripts/install-fseventsd-watchdog.sh
```

```bash
sudo sh <main clone>/machine-health-schedule/scripts/install-fseventsd-watchdog.sh --uninstall
```

The installer copies the watchdog to `/usr/local/libexec/machine-health/`, root-owned. launchd
must not run a root job from the repo: any process running as the user could edit that file and
get root.

After the user says it ran, verify read-only:

```bash
launchctl print system/com.user.machine-health.fseventsd | grep -E 'state|run interval'; ls -l /usr/local/libexec/machine-health/
```

Uninstalled → the `launchctl print` errors with "Could not find service" and the directory is gone.

## Report

Per piece: installed / uninstalled / left as it was, plus the observed proof line (`last-run`
time, `launchctl print` state). Unverified — e.g. the user hasn't run the `sudo` line yet — says so.
