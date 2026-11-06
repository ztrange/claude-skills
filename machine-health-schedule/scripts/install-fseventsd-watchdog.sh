#!/bin/sh
# Install (or --uninstall) the root fseventsd watchdog. Run with sudo:
#   sudo sh <skill>/scripts/install-fseventsd-watchdog.sh
#   sudo sh <skill>/scripts/install-fseventsd-watchdog.sh --uninstall
# It copies the watchdog to a root-owned path rather than pointing launchd at this repo: a root job
# running a user-writable file is a privilege escalation. Re-run after changing the watchdog.
set -eu
LABEL=com.user.machine-health.fseventsd
DEST_DIR=/usr/local/libexec/machine-health
DEST=$DEST_DIR/fseventsd-watchdog.sh
PLIST=/Library/LaunchDaemons/$LABEL.plist

[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

launchctl bootout "system/$LABEL" 2>/dev/null || true
if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$PLIST" "$DEST"
  rmdir "$DEST_DIR" 2>/dev/null || true
  echo "uninstalled; log kept at /var/log/machine-health-fseventsd.log"
  exit 0
fi

src="$(cd "$(dirname "$0")" && pwd)/fseventsd-watchdog.sh"
install -d -o root -g wheel -m 755 "$DEST_DIR"
install -o root -g wheel -m 755 "$src" "$DEST"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/sh</string><string>$DEST</string></array>
  <key>StartInterval</key><integer>120</integer>
  <key>ProcessType</key><string>Background</string>
</dict>
</plist>
EOF
chown root:wheel "$PLIST"
chmod 644 "$PLIST"
plutil -lint "$PLIST" >/dev/null
launchctl bootstrap system "$PLIST"
launchctl print "system/$LABEL" | grep -E '^\s*(state|run interval|program)' || true
echo "installed: $DEST every 120s; log /var/log/machine-health-fseventsd.log"
