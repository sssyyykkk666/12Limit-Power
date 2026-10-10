#!/bin/bash
set -euo pipefail
BASE='/Library/Application Support/FYQMac'
SRC=$(cd "$(dirname "$0")/.." && pwd)
CONTROL_HOME=$(/usr/bin/defaults read "$BASE/device" home)
# Escape XML text for launchd's queue path.
QUEUE_XML=$(printf '%s' "$CONTROL_HOME/Library/Application Support/FYQMacControl" | /usr/bin/sed 's/\&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
cp "$SRC/target-cpu.txt" "$BASE/target-cpu.txt"
chown root:wheel "$BASE/target-cpu.txt"; chmod 644 "$BASE/target-cpu.txt"
cp "$SRC/scripts/controller.sh" "$BASE/controller.sh"
cp "$SRC/scripts/power-policy.pl" "$BASE/power-policy.pl"
chown root:wheel "$BASE/power-policy.pl"
chmod 644 "$BASE/power-policy.pl"
chown root:wheel "$BASE/controller.sh"
chmod 755 "$BASE/controller.sh"
cat > /Library/LaunchDaemons/local.fyqmac.power.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>local.fyqmac.power</string>
<key>ProgramArguments</key><array><string>/bin/bash</string><string>/Library/Application Support/FYQMac/controller.sh</string></array>
<key>RunAtLoad</key><true/>
<key>QueueDirectories</key><array><string>$QUEUE_XML</string></array>
<key>ThrottleInterval</key><integer>3</integer>
<key>StandardOutPath</key><string>/Library/Application Support/FYQMac/launchd.log</string>
<key>StandardErrorPath</key><string>/Library/Application Support/FYQMac/launchd.log</string>
</dict></plist>
PLIST
chown root:wheel /Library/LaunchDaemons/local.fyqmac.power.plist
chmod 644 /Library/LaunchDaemons/local.fyqmac.power.plist
/bin/launchctl bootout system/local.fyqmac.power 2>/dev/null || true
/bin/launchctl bootstrap system /Library/LaunchDaemons/local.fyqmac.power.plist
