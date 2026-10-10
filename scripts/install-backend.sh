#!/bin/bash
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
DEST='/Library/Application Support/FYQMac'
mkdir -p "$DEST"
if [ -e "$DEST/voltageshift" ]; then echo 'Backend already exists; stopping to preserve existing install.'; exit 1; fi
cp "$BASE/vendor/VoltageShift/voltageshift" "$DEST/"
cp -R "$BASE/vendor/VoltageShift/VoltageShift.kext" "$DEST/"
cp "$BASE/vendor/VoltageShift/LICENSE" "$DEST/VoltageShift-LICENSE"
chown -R root:wheel "$DEST"
chmod -R go-w "$DEST"
chmod 755 "$DEST/voltageshift"
cd "$DEST"
/usr/bin/kextutil -v 1 "$DEST/VoltageShift.kext" > "$DEST/install.log" 2>&1 || { cat "$DEST/install.log"; exit 1; }
./voltageshift info > "$DEST/original-info.txt" 2>&1
./voltageshift read 610 > "$DEST/original-msr610.txt" 2>&1
./voltageshift read 1a0 > "$DEST/original-msr1a0.txt" 2>&1
cat "$DEST/original-info.txt"
