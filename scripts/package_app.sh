#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release

APP="build/VirtualDesktopBadge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp ".build/release/virtualdesktopbadge" "$APP/Contents/MacOS/VirtualDesktopBadge"

# Build the app icon (.icns) from the generator and place it in Resources.
mkdir -p "$APP/Contents/Resources"
ICONSET="build/VirtualDesktopBadge.iconset"
rm -rf "$ICONSET"
swift scripts/make_icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Virtual Desktop Badge</string>
  <key>CFBundleDisplayName</key><string>Virtual Desktop Badge</string>
  <key>CFBundleIdentifier</key><string>com.local.virtualdesktopbadge</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>VirtualDesktopBadge</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
