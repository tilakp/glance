#!/bin/bash
# Builds Glance.app from the SwiftPM executable and installs it to
# /Applications, which is where a login item has to point to survive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Glance.app"
INSTALLED="/Applications/Glance.app"

echo "==> Compiling"
swift build -c release --package-path "$ROOT"
BINARY="$(swift build -c release --package-path "$ROOT" --show-bin-path)/Glance"

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Glance"

echo "==> Rendering icon"
ICONSET="$BUILD/Glance.iconset"
rm -rf "$ICONSET"
swift "$ROOT/Tools/make-icon.swift" "$ICONSET" > /dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Glance</string>
    <key>CFBundleDisplayName</key><string>Glance</string>
    <key>CFBundleIdentifier</key><string>com.tilak.glance</string>
    <key>CFBundleExecutable</key><string>Glance</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <!-- Menu bar only: no Dock icon, no app switcher entry. -->
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP" 2>/dev/null

echo "==> Installing to $INSTALLED"
if [ ! -w /Applications ]; then
    echo "    /Applications is not writable by $(whoami)."
    echo "    Re-run with: sudo $0"
    exit 1
fi

# Note whether it was already running, so the install does not silently
# leave the user without the app they had a moment ago.
WAS_RUNNING=no
if pgrep -x Glance > /dev/null; then
    WAS_RUNNING=yes
    echo "    Quitting the running copy"
    killall Glance 2>/dev/null || true
    for _ in $(seq 1 20); do
        pgrep -x Glance > /dev/null || break
        sleep 0.25
    done
fi

# Guarded: this is an rm -rf against a system directory, so refuse anything
# that is not exactly the bundle we mean to replace.
if [ -e "$INSTALLED" ]; then
    case "$INSTALLED" in
        /Applications/Glance.app) rm -rf "$INSTALLED" ;;
        *) echo "    Refusing to remove $INSTALLED"; exit 1 ;;
    esac
fi
cp -R "$APP" "$INSTALLED"
# Re-sign in place: copying can disturb the bundle's seal.
codesign --force --sign - "$INSTALLED" 2>/dev/null

if [ "$WAS_RUNNING" = yes ]; then
    echo "    Relaunching"
    open "$INSTALLED"
fi

echo "==> Installed $INSTALLED"
echo "    (staged copy left at $APP)"
