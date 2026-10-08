#!/bin/bash
set -euo pipefail
BASE=/Users/skyfu/Downloads/FYQMac
/usr/bin/sudo -u skyfu /bin/launchctl bootout gui/501/local.fyqmac.menu 2>/dev/null || true
if [ ! -e "$BASE/build/FYQMac.previous.app" ]; then cp -R /Applications/FYQMac.app "$BASE/build/FYQMac.previous.app"; fi
cp -R "$BASE/build/FYQMac.app/Contents/." /Applications/FYQMac.app/Contents/
chown -R root:wheel /Applications/FYQMac.app
/usr/bin/codesign --verify --deep --strict /Applications/FYQMac.app
/usr/bin/sudo -H -u skyfu /bin/bash "$BASE/scripts/deploy-menu.sh"
