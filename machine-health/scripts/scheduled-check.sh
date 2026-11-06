#!/bin/sh
# Run by launchd (see references/launchd.plist). No model, no tokens: it runs the snapshot, and
# only when a WARN or CRIT finding exists does it keep the report and post a notification.
# Clean runs leave nothing behind but the timestamp in last-ok.
set -u
here=$(cd "$(dirname "$0")" && pwd)
logdir="$HOME/Library/Logs/machine-health"
mkdir -p "$logdir"
report="$logdir/$(date +%Y-%m-%dT%H%M%S).txt"

if /usr/bin/python3 -I "$here/snapshot.py" --check >"$report" 2>&1; then
  rm -f "$report"
  date >"$logdir/last-ok"
  exit 0
fi

ln -sf "$report" "$logdir/latest.txt"
first=$(grep -m1 -E '^  (CRIT|WARN)' "$report" | sed 's/^ *//; s/"/\\"/g')
/usr/bin/osascript -e "display notification \"$first\" with title \"machine-health\" subtitle \"run /machine-health for the full picture\""
# Keep the newest 50 reports; never touches anything outside $logdir.
ls -1t "$logdir"/20*.txt 2>/dev/null | tail -n +51 | while IFS= read -r old; do rm -f "$old"; done
exit 0
