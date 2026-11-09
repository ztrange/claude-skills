#!/bin/sh
# Run every 30 min by the user LaunchAgent that `/dev-tools machine-health` installs — as a copy in
# ~/Library/Application Support/machine-health, so edit here then re-install. No model, no
# tokens. It runs the snapshot with --fix, whose only automatic action is killing leaked Claude
# Bash shells. A report is kept when anything was fixed or a WARN/CRIT remains; only the latter
# posts a notification. Clean runs leave nothing but the timestamp in last-ok.
set -u
here=$(cd "$(dirname "$0")" && pwd)
logdir="$HOME/Library/Logs/machine-health"
mkdir -p "$logdir"
report="$logdir/$(date +%Y-%m-%dT%H%M%S).txt"

/usr/bin/python3 -I "$here/snapshot.py" --quiet --check --fix >"$report" 2>&1
status=$?
date >"$logdir/last-run"

if [ "$status" = 0 ] && ! grep -q '^  FIXED' "$report"; then
  rm -f "$report"
  date >"$logdir/last-ok"
  exit 0
fi

ln -sf "$report" "$logdir/latest.txt"
grep '^  FIXED' "$report" | sed "s/^/$(date '+%Y-%m-%d %H:%M') /" >>"$logdir/fixed.log"
if [ "$status" != 0 ]; then
  first=$(grep -m1 -E '^  (CRIT|WARN)' "$report" | sed 's/^ *//; s/"/\\"/g')
  [ -n "$first" ] || first="snapshot failed (exit $status); see latest.txt"
  /usr/bin/osascript -e "display notification \"$first\" with title \"machine-health\" subtitle \"run /dev-tools machine-health for the full picture\""
fi
# Keep the newest 50 reports; touches nothing outside $logdir.
ls -1t "$logdir"/20*.txt 2>/dev/null | tail -n +51 | while IFS= read -r old; do rm -f "$old"; done
exit 0
