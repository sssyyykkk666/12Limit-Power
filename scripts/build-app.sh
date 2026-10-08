#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP='build/12Limit Power.app'
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
/usr/bin/swiftc -O -target x86_64-apple-macosx13.0 src/PowerApp.swift -o "$APP/Contents/MacOS/12LimitPower"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.fyqmac.menu</string>
<key>CFBundleName</key><string>12Limit Power</string>
<key>CFBundleExecutable</key><string>12LimitPower</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>120</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.2.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/swiftc -O scripts/make-icon.swift -o build/make-icon
build/make-icon build/PowerIcon.iconset
/usr/bin/iconutil -c icns build/PowerIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cp README.md LICENSE scripts/uninstall.sh "$APP/Contents/Resources/"
/usr/bin/codesign --force --sign - "$APP"
