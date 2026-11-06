---
name: machine-health
description: >-
  Check this Mac for undue hardware use and clean up what is leaking: load against cores, memory
  and swap, CPU grouped by the Claude session or process tree that owns it, orphaned and leaked
  processes (Claude Bash shells left looping), zombies, idle week-old sessions, and runaway
  fseventsd / Spotlight. Use when the user says "machine health", "check hardware use", "orphan
  processes", "why is my Mac slow", "the computer is hot / beachballing", "what's eating CPU",
  "kill the leaks", "fseventsd is stuck", or asks to schedule that check. Read-only until the user
  says yes to a specific kill; never kills a live session's tree or anything outside their user
  without them running it.
---

# Machine health — measure, attribute, then ask

macOS only. Everything here reads first; nothing is killed without a yes naming the pid.

## 1. Snapshot

```bash
python3 -I <this skill>/scripts/snapshot.py
```

About 5 s (a 2 s `top` sample — `ps %cpu` is a decaying average and misses a burst). It prints
load/memory/swap, CPU by tree, and findings, each with the command that would fix it. `--check`
exits 1 on any WARN/CRIT; `--quiet` prints findings only.

**CPU by tree** is the table that answers "who": every busy process is summed into its nearest
`claude` CLI ancestor (a session, with its cwd) or, failing that, its top ancestor below launchd.
Load is a 1/5/15-minute average — if load is high but the tree table is quiet, the burst just
ended; re-run before acting.

## 2. Classify — what may be killed, and by whom

| Finding | Verdict |
|---|---|
| Leaked Claude Bash shell (PPID 1, runs from `.claude/shell-snapshots/`, older than 10 min) | **Ask once, then kill** — `kill <pid>`. Its session is gone; nothing reads its output |
| Orphan candidate (PPID 1, not a launchd job, no live children, not an app or system path) | **Ask** — show the command; some tools detach on purpose |
| Tree over 4 cores | **Report the owner** (session + cwd). It is somebody's work: name it, don't kill it. If the user wants it stopped, `kill -TERM -- -<pgid>`, never `-9` first |
| Idle `claude` session > 24 h | **Report** pid, age, RSS, cwd. Closing it is the user's call in that terminal/app |
| Zombies | **Report the parent** — a zombie can't be killed; only its parent reaping it (or dying) clears it |
| Claude.app main process > 80% | **Report** — restart clears it but ends every desktop session it hosts |
| `mds` / `mdworker` busy | **Report the churning tree** and suggest a Spotlight exclusion (System Settings → Spotlight → Search Privacy). Changing it is the user's |
| `fseventsd` busy | See §3 |

Never: kill a pid not in the latest snapshot, a process owned by another user, a launchd job, or
anything by name pattern (`pkill -f`) — re-check the pid's command right before `kill`:

```bash
ps -o command= -p <pid> | grep -q '<expected fragment>' && kill <pid>
```

Then re-run `ps -p <pid>` and say gone or still alive. `-9` only after a TERM was ignored for 10 s.

## 3. Runaway fseventsd — the one that has wedged this machine

fseventsd runs as root and launchd respawns it, so restarting it is safe but needs `sudo`, which
you don't have. Give the user these, in order — the second only if the first didn't take:

```bash
sudo killall fseventsd
```

```bash
pgrep -x fseventsd && sudo killall -9 fseventsd
```

Then find the cause, or it comes back: it is a file-event storm — a test suite, build or watcher
creating and deleting files fast in a watched tree. The CPU-by-tree table usually names it; stop or
throttle that first, or the restart only buys minutes.

## 4. Report

One line of load/memory/swap, then the top trees by owner, then findings grouped as **Killed**
(pid, command, confirmed gone), **Needs you** (with the ready command), **Left alone** (and why).
A finding you couldn't measure — e.g. `lsof` returned no cwd — says so.

## 5. Scheduling

Ask which; both create persistent config, so neither happens without a yes.

| Option | Cost | Can it act? |
|---|---|---|
| **launchd + `scripts/scheduled-check.sh`** (recommended) | $0, ~1 s CPU per run | No — notifies on WARN/CRIT and keeps the report in `~/Library/Logs/machine-health/` (`latest.txt`); you run `/machine-health` to act |
| Desktop-app scheduled task running `/machine-health` | A model run every time, findings or not | Only report; it should not kill unattended |

Cloud routines (`/schedule`) can't see this machine — not an option.

For launchd, fill `references/launchd.plist` (template, every 30 min, `Nice 10`) with the **main
clone's** path to this skill, write it to `~/Library/LaunchAgents/com.user.machine-health.plist`,
and give the user the `launchctl bootstrap` line from the template's header to run — then verify
with `launchctl print gui/$(id -u)/com.user.machine-health | grep -E 'state|runs'`.
