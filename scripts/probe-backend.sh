#!/bin/bash
set -euo pipefail
DEST='/Library/Application Support/FYQMac'
cd "$DEST"
/usr/bin/kextutil -v 1 "$DEST/VoltageShift.kext" > "$DEST/install.log" 2>&1 || { cat "$DEST/install.log"; exit 1; }
./voltageshift info > "$DEST/original-info.txt" 2>&1
./voltageshift read 610 > "$DEST/original-msr610.txt" 2>&1
./voltageshift read 1a0 > "$DEST/original-msr1a0.txt" 2>&1
cat "$DEST/original-info.txt"
