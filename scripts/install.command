#!/bin/bash
# Open from the distribution root. This script never changes SIP.
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")"
[ -f target-cpu.txt ] || { echo 'Run Install.command from the extracted release folder.'; exit 1; }
TARGET_CPU=$(cat target-cpu.txt)
case "$TARGET_CPU" in m3-7Y32|i7-7Y75) ;; *) echo 'Invalid target'; exit 1;; esac
[ "$(sysctl -n hw.model)" = MacBook10,1 ] && [[ "$(sysctl -n machdep.cpu.brand_string)" = *"$TARGET_CPU"* ]] || { echo "Wrong package: requires MacBook10,1 / $TARGET_CPU"; exit 1; }
# Keep the administrator process out of Downloads (macOS privacy restrictions).
STAGE=$(mktemp -d /private/tmp/12limit-install.XXXXXX)
for entry in scripts vendor build target-cpu.txt; do /usr/bin/ditto "$entry" "$STAGE/$entry"; done
sudo -v
sudo chown -R root:wheel "$STAGE/vendor/VoltageShift/VoltageShift.kext"
sudo chmod -R go-w "$STAGE/vendor/VoltageShift/VoltageShift.kext"
if ! /usr/sbin/ioreg -r -c VoltageShiftAnVMSR | /usr/bin/grep -q VoltageShiftAnVMSR; then
  if ! sudo /usr/bin/kextutil -v 1 "$STAGE/vendor/VoltageShift/VoltageShift.kext"; then
    echo 'Driver not loaded. See README: Recovery mode, extension approval, restart, then run this installer again.'
    exit 1
  fi
fi
sudo /bin/bash "$STAGE/scripts/setup-device.sh"
/bin/bash "$STAGE/scripts/deploy-menu.sh"
/usr/bin/open '/Applications/12Limit Power.app'
echo 'Installed. Original settings are retained on first installation. Choose a profile to apply limits.'
