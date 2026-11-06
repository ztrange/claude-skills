#!/bin/sh
# Install (or --uninstall) the per-user LaunchAgent that runs machine-health's scheduled-check.sh
# every 30 min. No sudo.
#   sh install-agent.sh              install or refresh
#   sh install-agent.sh --uninstall  remove the agent and its copied scripts; reports stay
#
# The agent runs a COPY in ~/Library/Application Support/machine-health, not the repo. macOS
# privacy protection (TCC) denies launchd jobs access to ~/Documents, ~/Desktop and ~/Downloads:
# pointing the agent at the repo failed with exit 126, "Operation not permitted". Granting /bin/sh
# Full Disk Access would fix it by opening every protected folder to every shell script — rejected.
# Consequence: a change to snapshot.py or scheduled-check.sh is live only after re-running this.
# Sources come from the MAIN clone, resolved through `git worktree list`, so a worktree's
# unmerged edits never get installed.
set -eu
LABEL=com.user.machine-health
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
DEST="$HOME/Library/Application Support/machine-health"
LOGS="$HOME/Library/Logs/machine-health"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$PLIST" "$DEST/scheduled-check.sh" "$DEST/snapshot.py"
  rmdir "$DEST" 2>/dev/null || true
  if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then echo "FAILED: $LABEL still loaded" >&2; exit 1; fi
  echo "uninstalled $LABEL; reports kept in $LOGS"
  exit 0
fi

here=$(cd "$(dirname "$0")" && pwd)
main=$(git -C "$here" worktree list --porcelain | head -1 | cut -d' ' -f2-)
src="$main/machine-health/scripts"
for f in scheduled-check.sh snapshot.py; do
  [ -f "$src/$f" ] || { echo "not found: $src/$f (is machine-health merged to main and pulled?)" >&2; exit 1; }
done

mkdir -p "$DEST" "$LOGS" "$HOME/Library/LaunchAgents"
install -m 755 "$src/scheduled-check.sh" "$src/snapshot.py" "$DEST/"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/sh</string><string>$DEST/scheduled-check.sh</string></array>
  <key>StartInterval</key><integer>1800</integer>
  <key>Nice</key><integer>10</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardErrorPath</key><string>$LOGS/agent.err</string>
</dict>
</plist>
EOF
plutil -lint "$PLIST" >/dev/null
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl print "$DOMAIN/$LABEL" >/dev/null
echo "installed $LABEL: copy of $src in $DEST, every 1800s"
