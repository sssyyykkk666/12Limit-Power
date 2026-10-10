#!/bin/bash
# Run as administrator. Restore and verify before removing this installation.
set -euo pipefail
BASE='/Library/Application Support/FYQMac'
[ "$(id -u)" = 0 ] || { echo 'Run with sudo.'; exit 1; }
CONTROL_UID=$(/usr/bin/defaults read "$BASE/device" uid)
CONTROL_HOME=$(/usr/bin/defaults read "$BASE/device" home)
CONTROL_USER=$(id -nu "$CONTROL_UID")
/bin/launchctl bootout "gui/$CONTROL_UID"/local.fyqmac.menu 2>/dev/null || true
/usr/bin/pkill -u "$CONTROL_UID" -x FYQMac 2>/dev/null || true
/usr/bin/pkill -u "$CONTROL_UID" -x 12LimitPower 2>/dev/null || true
/bin/launchctl bootout system/local.fyqmac.power 2>/dev/null || true
/usr/bin/sudo -u "$CONTROL_USER" /bin/bash -c 'printf "original\n" > "$1"' -- "$CONTROL_HOME/Library/Application Support/FYQMacControl/request"
/bin/bash "$BASE/controller.sh"
/usr/bin/grep -q '^原始设置.*已回读验证' "$BASE/status.txt" || { echo 'Restore failed; preserving files for recovery.'; exit 1; }
/usr/bin/kextunload -b com.sicreative.VoltageShift || { echo 'Driver unload failed; preserving installation. Restart and retry.'; exit 1; }
rm -f /Library/LaunchDaemons/local.fyqmac.power.plist
rm -f "$CONTROL_HOME/Library/LaunchAgents/local.fyqmac.menu.plist"
rm -rf '/Applications/12Limit Power.app'
rm -rf /Applications/FYQMac.app
rm -rf '/Library/Application Support/FYQMac'
echo 'Original CPU settings restored and 12Limit Power removed. Git and Apple development tools remain installed.'
