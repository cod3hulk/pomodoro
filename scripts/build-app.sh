#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$(pwd)/build/Pomodoro.app"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Pomodoro" "$APP/Contents/MacOS/Pomodoro"
mkdir -p "$APP/Contents/Resources"
cp Resources/tick.wav "$APP/Contents/Resources/tick.wav"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Pomodoro</string>
<key>CFBundleIdentifier</key><string>dev.cod3hulk.pomodoro</string>
<key>CFBundleName</key><string>Pomodoro</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
