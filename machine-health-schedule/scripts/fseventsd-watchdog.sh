#!/bin/sh
# Root LaunchDaemon body: restart fseventsd when it stays pegged, so a file-event storm can't
# wedge the machine. Installed as a root-owned COPY by install-fseventsd-watchdog.sh — a root job
# must never execute a file the user account can edit, or any user process could become root.
#
# One run = one 3 s CPU sample. A strike is a sample >= THRESHOLD; STRIKES consecutive strikes
# (launchd runs this every 120 s, so ~4 min sustained) trigger `killall`, then `killall -9` if the
# same pid is still there 10 s later. launchd respawns fseventsd. After a restart, COOLDOWN
# seconds pass before another one, so a storm that persists produces a log line, not a kill loop.
#
# The MH_* overrides exist for testing against a stand-in process; production uses the defaults.
set -u
TARGET=${MH_TARGET:-fseventsd}
THRESHOLD=${MH_THRESHOLD:-80}
STRIKES=${MH_STRIKES:-2}
COOLDOWN=${MH_COOLDOWN:-900}
STATE=${MH_STATE_DIR:-/var/db/machine-health}
LOG=${MH_LOG:-/var/log/machine-health-fseventsd.log}

mkdir -p "$STATE"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

pid=$(pgrep -x "$TARGET" | head -1)
[ -n "$pid" ] || { echo 0 >"$STATE/strikes"; exit 0; }

cpu=$(top -l 2 -s 3 -pid "$pid" -stats cpu | grep -E "^[0-9.]+$" | tail -1 | cut -d. -f1)
case "$cpu" in ''|*[!0-9]*) log "could not read CPU for $TARGET pid $pid (got '$cpu')"; exit 0 ;; esac

strikes=$(cat "$STATE/strikes" 2>/dev/null || echo 0)
if [ "$cpu" -lt "$THRESHOLD" ]; then
  echo 0 >"$STATE/strikes"
  exit 0
fi
strikes=$((strikes + 1))
echo "$strikes" >"$STATE/strikes"
log "strike $strikes/$STRIKES: $TARGET pid $pid at ${cpu}%"
[ "$strikes" -ge "$STRIKES" ] || exit 0

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
log "restarted $TARGET (old pid $pid at ${cpu}%): $how; new pid $(pgrep -x "$TARGET" | head -1)"
