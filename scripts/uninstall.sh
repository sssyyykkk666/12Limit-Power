#!/bin/bash
# Run as administrator. Restore and verify before removing this installation.
set -euo pipefail
BASE='/Library/Application Support/FYQMac'
/bin/launchctl bootout gui/501/local.fyqmac.menu 2>/dev/null || true
/usr/bin/pkill -u 501 -x FYQMac 2>/dev/null || true
/usr/bin/pkill -u 501 -x 12LimitPower 2>/dev/null || true
/bin/launchctl bootout system/local.fyqmac.power 2>/dev/null || true
/usr/bin/sudo -u skyfu /bin/sh -c 'printf "original\n" > "/Users/skyfu/Library/Application Support/FYQMacControl/request"'
/bin/bash "$BASE/controller.sh"
/usr/bin/grep -q '^原始设置.*已回读验证' "$BASE/status.txt" || { echo 'Restore failed; preserving files for recovery.'; exit 1; }
/usr/bin/kextunload -b com.sicreative.VoltageShift || { echo 'Driver unload failed; preserving installation. Restart and retry.'; exit 1; }
rm -f /Library/LaunchDaemons/local.fyqmac.power.plist
rm -f /Users/skyfu/Library/LaunchAgents/local.fyqmac.menu.plist
rm -rf '/Applications/12Limit Power.app'
rm -rf /Applications/FYQMac.app
rm -rf '/Library/Application Support/FYQMac'
echo 'Original CPU settings restored and 12Limit Power removed. Git and Apple development tools remain installed.'
