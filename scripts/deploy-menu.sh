#!/bin/bash
set -euo pipefail
mkdir -p /Users/skyfu/Library/LaunchAgents
cat > /Users/skyfu/Library/LaunchAgents/local.fyqmac.menu.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>local.fyqmac.menu</string>
<key>ProgramArguments</key><array><string>/Applications/FYQMac.app/Contents/MacOS/FYQMac</string></array>
<key>RunAtLoad</key><true/>
<key>ProcessType</key><string>Interactive</string>
</dict></plist>
PLIST
/bin/launchctl bootout gui/501/local.fyqmac.menu 2>/dev/null || true
/bin/launchctl bootstrap gui/501 /Users/skyfu/Library/LaunchAgents/local.fyqmac.menu.plist
