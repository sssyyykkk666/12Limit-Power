#!/bin/bash
# Upgrade this existing MacBook installation; preserve its original baseline.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo 'Administrator privileges are required.'; exit 1; }
SRC=$(cd "$(dirname "$0")/.." && pwd)
BASE='/Library/Application Support/FYQMac'
APP='/Applications/12Limit Power.app'
[ -f "$BASE/baseline.plist" ] || { echo 'Existing original backup required.'; exit 1; }
/usr/bin/codesign --verify --deep --strict "$SRC/build/12Limit Power.app"
BACKUP="$BASE/backups/v1.0"
mkdir -p "$BACKUP"; chmod 700 "$BASE/backups" "$BACKUP"
for name in baseline.plist controller.sh selected.txt; do
  [ -e "$BACKUP/$name" ] || cp -p "$BASE/$name" "$BACKUP/$name"
done
if [ -d /Applications/FYQMac.app ] && [ ! -e "$BACKUP/FYQMac.app" ]; then /usr/bin/ditto /Applications/FYQMac.app "$BACKUP/FYQMac.app"; fi
if [ -d "$APP" ] && [ ! -e "$BASE/backups/pre-upgrade.app" ]; then /usr/bin/ditto "$APP" "$BASE/backups/pre-upgrade.app"; fi
if [ -f /Users/skyfu/Library/LaunchAgents/local.fyqmac.menu.plist ]; then ENABLED=1; else ENABLED=0; fi
/usr/bin/sudo -u skyfu /bin/launchctl bootout gui/501/local.fyqmac.menu 2>/dev/null || true
/usr/bin/pkill -u 501 -x FYQMac 2>/dev/null || true
/usr/bin/pkill -u 501 -x 12LimitPower 2>/dev/null || true
/bin/launchctl bootout system/local.fyqmac.power 2>/dev/null || true
/usr/bin/ditto "$SRC/build/12Limit Power.app" "$APP"
chown -R root:wheel "$APP"
/bin/bash "$SRC/scripts/deploy-controller.sh"
# Boot service re-applies the last saved configuration; wait for its versioned state.
for attempt in {1..20}; do [ ! -f "$BASE/settings.json" ] || break; sleep 1; done
[ -f "$BASE/settings.json" ] || { echo 'Backend did not report successful configuration; preserving backups.'; exit 1; }
if [ "$ENABLED" = 1 ]; then /usr/bin/sudo -H -u skyfu /bin/bash "$SRC/scripts/deploy-menu.sh"; fi
/usr/bin/codesign --verify --deep --strict "$APP"
cmp "$BASE/baseline.plist" "$BACKUP/baseline.plist"
rm -rf /Applications/FYQMac.app
printf '12Limit Power 1.1.0 installed; original baseline preserved.\n'
