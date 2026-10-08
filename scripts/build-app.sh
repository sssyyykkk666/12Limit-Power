#!/bin/bash
set -euo pipefail
cd /Users/skyfu/Downloads/FYQMac
APP='build/FYQMac.app'
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
/usr/bin/swiftc -O -target x86_64-apple-macosx13.0 src/FYQMac.swift -o "$APP/Contents/MacOS/FYQMac"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.fyqmac.menu</string>
<key>CFBundleName</key><string>FYQMac</string>
<key>CFBundleExecutable</key><string>FYQMac</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
cp README.md LICENSE scripts/uninstall.sh "$APP/Contents/Resources/"
/usr/bin/codesign --force --sign - "$APP"
