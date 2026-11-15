#!/bin/sh
# Root LaunchDaemon body: restart fseventsd when it stays pegged or has leaked memory, so neither
# a file-event storm nor a leak can wedge the machine. Installed as a root-owned COPY by install-fseventsd-watchdog.sh — a root job
# must never execute a file the user account can edit, or any user process could become root.
#
# One run = one 5 s CPU sample. A strike is a sample >= THRESHOLD; STRIKES consecutive strikes
# (launchd runs this every 120 s, so ~4 min sustained) trigger `killall`, then `killall -9` if the
# same pid is still there 10 s later. launchd respawns fseventsd. After a restart, COOLDOWN
# seconds pass before another one, so a storm that persists produces a log line, not a kill loop.
#
# Memory: a footprint >= MEM_MB (top's MEM, which counts compressed and swapped pages; ps RSS does
# not) restarts it on the first reading, no strikes — a leak never shrinks on its own. On
# 2026-11-15 a leaked fseventsd held 27 GB at ~20% CPU and filled swap; the CPU rule never fired.
#
# The MH_* overrides exist for testing against a stand-in process; production uses the defaults.
set -u
TARGET=${MH_TARGET:-fseventsd}
THRESHOLD=${MH_THRESHOLD:-80}
STRIKES=${MH_STRIKES:-2}
COOLDOWN=${MH_COOLDOWN:-900}
STATE=${MH_STATE_DIR:-/var/db/machine-health}
LOG=${MH_LOG:-/var/log/machine-health-fseventsd.log}
MEM_MB=${MH_MEM_MB:-4096}

mkdir -p "$STATE"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

pid=$(pgrep -x "$TARGET" | head -1)
[ -n "$pid" ] || { echo 0 >"$STATE/strikes"; exit 0; }

# CPU% = cumulative CPU time gained over SAMPLE seconds. Not `top`: under launchd as root on a
# loaded machine, `top -l 2 -s 3 -pid` took 20-40 s per run and printed no parseable CPU line, so
# every run logged "could not read CPU" and the watchdog could never strike — blind, not hung.
# `ps -o time=` prints [h:]mm:ss.cc.
SAMPLE=${MH_SAMPLE:-5}
cputime_cs() { ps -o time= -p "$1" | awk -F: '{s=0; for (i=1; i<=NF; i++) s=s*60+$i; printf "%d", s*100}'; }
c1=$(cputime_cs "$pid"); sleep "$SAMPLE"; c2=$(cputime_cs "$pid")
case "$c1$c2" in ''|*[!0-9]*) log "could not read CPU time for $TARGET pid $pid (got '$c1' '$c2')"; exit 0 ;; esac
[ -n "$c1" ] && [ -n "$c2" ] || { log "$TARGET pid $pid vanished mid-sample"; exit 0; }
cpu=$(( (c2 - c1) / SAMPLE ))

# Footprint in MB from one `top -l 1` sample (~0.6 s; the slow case that dropped top above was the
# two-sample `-l 2 -s 3`). MEM prints as 4592K, 1004M+, 27G-. Unreadable = no memory verdict, logged.
mem=$(top -l 1 -pid "$pid" -stats pid,mem 2>/dev/null | awk -v p="$pid" '
  $1 == p { v = $2; sub(/[+-]$/, "", v); u = substr(v, length(v)); n = substr(v, 1, length(v) - 1)
            f = (u == "K") ? 1/1024 : (u == "M") ? 1 : (u == "G") ? 1024 : (u == "T") ? 1048576 : (u == "B") ? 1/1048576 : -1
            if (f > 0 && n ~ /^[0-9.]+$/) printf "%d", n * f }')
case "$mem" in ''|*[!0-9]*) log "could not read memory for $TARGET pid $pid"; mem=0 ;; esac

strikes=$(cat "$STATE/strikes" 2>/dev/null || echo 0)
if [ "$mem" -ge "$MEM_MB" ]; then
  why="memory ${mem} MB >= ${MEM_MB} MB"
  log "$TARGET pid $pid holds ${mem} MB (cpu ${cpu}%)"
elif [ "$cpu" -lt "$THRESHOLD" ]; then
  echo 0 >"$STATE/strikes"
  exit 0
else
  strikes=$((strikes + 1))
  echo "$strikes" >"$STATE/strikes"
  log "strike $strikes/$STRIKES: $TARGET pid $pid at ${cpu}%"
  [ "$strikes" -ge "$STRIKES" ] || exit 0
  why="cpu ${cpu}% on $strikes samples"
fi

now=$(date +%s)
last=$(cat "$STATE/last-restart" 2>/dev/null || echo 0)
if [ $((now - last)) -lt "$COOLDOWN" ]; then
  log "in cooldown ($((now - last))s since last restart); not restarting. The storm's source is still running."
  exit 0
fi

killall "$TARGET"
i=0
while [ $i -lt 10 ] && kill -0 "$pid" 2>/dev/null; do sleep 1; i=$((i + 1)); done
if kill -0 "$pid" 2>/dev/null; then
  killall -9 "$TARGET"
  sleep 2
  if kill -0 "$pid" 2>/dev/null; then how="FAILED: pid $pid survived SIGKILL"; else how="SIGKILL after SIGTERM was ignored 10s"; fi
else
  how="SIGTERM"
fi
echo "$now" >"$STATE/last-restart"
echo 0 >"$STATE/strikes"
log "restarted $TARGET (old pid $pid, $why): $how; new pid $(pgrep -x "$TARGET" | head -1)"
