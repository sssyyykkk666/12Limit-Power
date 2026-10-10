#!/bin/bash
# Capture this device's baseline only after its driver is approved and loaded.
set -euo pipefail
export LC_ALL=C
SRC=$(cd "$(dirname "$0")/.." && pwd)
TARGET_CPU=$(cat "$SRC/target-cpu.txt")
case "$TARGET_CPU" in m3-7Y32|i7-7Y75) ;; *) echo "Invalid target CPU"; exit 1;; esac
[ "$(id -u)" = 0 ] || { echo 'Run: sudo bash scripts/setup-device.sh'; exit 1; }
[ "$(sysctl -n hw.model)" = MacBook10,1 ] && [[ "$(sysctl -n machdep.cpu.brand_string)" = *"$TARGET_CPU"* ]] || { echo "Requires MacBook10,1 with $TARGET_CPU."; exit 1; }
CONTROL_USER=${SUDO_USER:?Run with sudo from your desktop account}
CONTROL_UID=$(id -u "$CONTROL_USER")
CONTROL_HOME=$(/usr/bin/dscl . -read "/Users/$CONTROL_USER" NFSHomeDirectory | /usr/bin/cut -d ' ' -f 2-)
BASE='/Library/Application Support/FYQMac'
if ! /usr/sbin/ioreg -r -c VoltageShiftAnVMSR | /usr/bin/grep -q VoltageShiftAnVMSR; then
 echo 'VoltageShift driver is not loaded. No hardware changes made. See README device setup.'; exit 1
fi
mkdir -p "$BASE"
chown root:wheel "$BASE"; chmod 755 "$BASE"
if [ -f "$BASE/device.plist" ]; then
 [ "$(/usr/bin/defaults read "$BASE/device" uid)" = "$CONTROL_UID" ] || { echo 'Different installation owner.'; exit 1; }
fi
cp "$SRC/vendor/VoltageShift/voltageshift" "$BASE/voltageshift"
[ -d "$BASE/VoltageShift.kext" ] || cp -R "$SRC/vendor/VoltageShift/VoltageShift.kext" "$BASE/"
chown -R root:wheel "$BASE/voltageshift" "$BASE/VoltageShift.kext"; chmod 755 "$BASE/voltageshift"
readreg() { "$BASE/voltageshift" read "$1" | /usr/bin/perl -ne 'if(/\(([01 ]+)\)/){$b=$1;$b=~s/ //g;print unpack("H16",pack("B64",$b)),"\n" if length($b)==64}'; }
if [ ! -e "$BASE/baseline.plist" ]; then
 units=$(readreg 606); power=$(readreg 610); turbo=$(readreg 1a0)
 [[ "$units" =~ ^[a-f0-9]{16}$ && "$power" =~ ^[a-f0-9]{16}$ && "$turbo" =~ ^[a-f0-9]{16}$ ]] || { echo 'MSR read failed; baseline not saved.'; exit 1; }
 [ "$(/usr/bin/perl -e 'printf "%d %d",hex($ARGV[0])&15,(hex($ARGV[0])>>16)&15' "$units")" = '3 10' ] || { echo 'Unexpected MSR units.'; exit 1; }
 /usr/bin/perl "$SRC/scripts/power-policy.pl" capabilities "$power" >/dev/null
 /usr/bin/defaults write "$BASE/baseline" power -string "$power"
 /usr/bin/defaults write "$BASE/baseline" turbo -string "$turbo"
 chmod 600 "$BASE/baseline.plist"
fi
/usr/bin/defaults write "$BASE/device" home -string "$CONTROL_HOME"
/usr/bin/defaults write "$BASE/device" uid -int "$CONTROL_UID"
chown root:wheel "$BASE/device.plist"; chmod 644 "$BASE/device.plist"
CONTROL_DIR="$CONTROL_HOME/Library/Application Support/FYQMacControl"
mkdir -p "$CONTROL_DIR"; chown "$CONTROL_UID" "$CONTROL_DIR"; chmod 700 "$CONTROL_DIR"
# First installation starts at the captured original settings.
[ -f "$BASE/selected.txt" ] || printf 'original\n' > "$BASE/selected.txt"
bash "$SRC/scripts/install-upgrade.sh"
