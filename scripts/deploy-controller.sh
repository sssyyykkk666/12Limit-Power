#!/bin/bash
set -euo pipefail
BASE='/Library/Application Support/FYQMac'
SRC='/Users/skyfu/Downloads/FYQMac'
cp "$SRC/scripts/controller.sh" "$BASE/controller.sh"
chown root:wheel "$BASE/controller.sh"
chmod 755 "$BASE/controller.sh"
cat > /Library/LaunchDaemons/local.fyqmac.power.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>local.fyqmac.power</string>
<key>ProgramArguments</key><array><string>/bin/bash</string><string>/Library/Application Support/FYQMac/controller.sh</string></array>
<key>RunAtLoad</key><true/>
<key>QueueDirectories</key><array><string>/Users/skyfu/Library/Application Support/FYQMacControl</string></array>
<key>ThrottleInterval</key><integer>3</integer>
<key>StandardOutPath</key><string>/Library/Application Support/FYQMac/launchd.log</string>
<key>StandardErrorPath</key><string>/Library/Application Support/FYQMac/launchd.log</string>
</dict></plist>
PLIST
chown root:wheel /Library/LaunchDaemons/local.fyqmac.power.plist
chmod 644 /Library/LaunchDaemons/local.fyqmac.power.plist
/bin/launchctl bootout system/local.fyqmac.power 2>/dev/null || true
/bin/launchctl bootstrap system /Library/LaunchDaemons/local.fyqmac.power.plist
