#!/bin/bash
# Upgrade this existing MacBook installation; preserve its original baseline.
set -euo pipefail
export LC_ALL=C
[ "$(id -u)" = 0 ] || { echo 'Administrator privileges are required.'; exit 1; }
SRC=$(cd "$(dirname "$0")/.." && pwd)
TARGET_CPU=$(cat "$SRC/target-cpu.txt")
case "$TARGET_CPU" in m3-7Y32|i7-7Y75) ;; *) echo 'Invalid target CPU'; exit 1;; esac
[ "$(sysctl -n hw.model)" = MacBook10,1 ] && [[ "$(sysctl -n machdep.cpu.brand_string)" = *"$TARGET_CPU"* ]] || { echo "Wrong package: requires $TARGET_CPU"; exit 1; }
[ "$(/usr/libexec/PlistBuddy -c 'Print :LimitTargetCPU' "$SRC/build/12Limit Power.app/Contents/Info.plist")" = "$TARGET_CPU" ] || { echo 'App/package CPU mismatch'; exit 1; }
BASE='/Library/Application Support/FYQMac'
APP='/Applications/12Limit Power.app'
CONTROL_USER=${SUDO_USER:?Run with sudo from your desktop account}
CONTROL_UID=$(id -u "$CONTROL_USER")
CONTROL_HOME=$(/usr/bin/dscl . -read "/Users/$CONTROL_USER" NFSHomeDirectory | /usr/bin/cut -d ' ' -f 2-)
[ "$(/usr/bin/defaults read "$BASE/device" uid)" = "$CONTROL_UID" ] || { echo 'Installation belongs to another account.'; exit 1; }
[ -f "$BASE/baseline.plist" ] || { echo 'Existing original backup required.'; exit 1; }
/usr/bin/codesign --verify --deep --strict "$SRC/build/12Limit Power.app"
BACKUP="$BASE/backups/v1.0"
mkdir -p "$BACKUP"; chmod 700 "$BASE/backups" "$BACKUP"
for name in baseline.plist controller.sh selected.txt; do
  if [ -e "$BASE/$name" ] && [ ! -e "$BACKUP/$name" ]; then cp -p "$BASE/$name" "$BACKUP/$name"; fi
done
if [ -d /Applications/FYQMac.app ] && [ ! -e "$BACKUP/FYQMac.app" ]; then /usr/bin/ditto /Applications/FYQMac.app "$BACKUP/FYQMac.app"; fi
if [ -d "$APP" ] && [ ! -e "$BASE/backups/v1.1.app" ]; then /usr/bin/ditto "$APP" "$BASE/backups/v1.1.app"; fi
if [ -f "$CONTROL_HOME/Library/LaunchAgents/local.fyqmac.menu.plist" ]; then ENABLED=1; else ENABLED=0; fi
/usr/bin/sudo -u "$CONTROL_USER" /bin/launchctl bootout "gui/$CONTROL_UID"/local.fyqmac.menu 2>/dev/null || true
/usr/bin/pkill -u "$CONTROL_UID" -x FYQMac 2>/dev/null || true
/usr/bin/pkill -u "$CONTROL_UID" -x 12LimitPower 2>/dev/null || true
/bin/launchctl bootout system/local.fyqmac.power 2>/dev/null || true
/usr/bin/ditto "$SRC/build/12Limit Power.app" "$APP"
chown -R root:wheel "$APP"
/bin/bash "$SRC/scripts/deploy-controller.sh"
# Boot service re-applies the last saved configuration; wait for its versioned state.
versionReady() { /usr/bin/perl -MJSON::PP -e 'local $/; $v=decode_json(<>); exit(($v->{backendVersion}//"") eq "1.3.0" ? 0:1)' "$BASE/settings.json" 2>/dev/null; }
for attempt in {1..20}; do if versionReady; then break; fi; sleep 1; done
# A previously queued refresh/save may have consumed the initial launch.
if ! versionReady; then /bin/bash "$BASE/controller.sh"; fi
versionReady || { echo 'Backend did not report successful configuration; preserving backups.'; exit 1; }
if [ "$ENABLED" = 1 ]; then /usr/bin/sudo -H -u "$CONTROL_USER" /bin/bash "$SRC/scripts/deploy-menu.sh"; fi
/usr/bin/codesign --verify --deep --strict "$APP"
cmp "$BASE/baseline.plist" "$BACKUP/baseline.plist"
rm -rf /Applications/FYQMac.app
printf '12Limit Power 1.3.0 installed; original baseline preserved.\n'
