#!/bin/bash
set -euo pipefail
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$HOME/Library/LaunchAgents/local.fyqmac.menu.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>local.fyqmac.menu</string>
<key>ProgramArguments</key><array><string>/Applications/12Limit Power.app/Contents/MacOS/12LimitPower</string><string>--background</string></array>
<key>RunAtLoad</key><true/>
<key>ProcessType</key><string>Interactive</string>
</dict></plist>
PLIST
/bin/launchctl bootout gui/$(id -u)/local.fyqmac.menu 2>/dev/null || true
/bin/launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/local.fyqmac.menu.plist"
