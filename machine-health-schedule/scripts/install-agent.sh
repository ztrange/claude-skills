#!/bin/sh
# Install (or --uninstall) the per-user LaunchAgent that runs machine-health's scheduled-check.sh
# every 30 min. No sudo. Points at the MAIN clone's machine-health, resolved from this script's
# own path through `git worktree list`, because a worktree path dies when its branch lands.
#   sh install-agent.sh              install or refresh
#   sh install-agent.sh --uninstall  remove the agent; reports in ~/Library/Logs/machine-health stay
set -eu
LABEL=com.user.machine-health
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$PLIST"
  if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then echo "FAILED: $LABEL still loaded" >&2; exit 1; fi
  echo "uninstalled $LABEL; reports kept in $HOME/Library/Logs/machine-health"
  exit 0
fi

here=$(cd "$(dirname "$0")" && pwd)
main=$(git -C "$here" worktree list --porcelain | head -1 | cut -d' ' -f2-)
check="$main/machine-health/scripts/scheduled-check.sh"
[ -f "$check" ] || { echo "not found: $check (is machine-health merged to main and pulled?)" >&2; exit 1; }

mkdir -p "$HOME/Library/LaunchAgents"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/sh</string><string>$check</string></array>
  <key>StartInterval</key><integer>1800</integer>
  <key>Nice</key><integer>10</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/machine-health/agent.err</string>
</dict>
</plist>
EOF
mkdir -p "$HOME/Library/Logs/machine-health"
plutil -lint "$PLIST" >/dev/null
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl print "$DOMAIN/$LABEL" >/dev/null
echo "installed $LABEL: $check every 1800s"
