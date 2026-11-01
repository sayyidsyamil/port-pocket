#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Port Pocket.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -swift-version 5 -O -target "$(uname -m)-apple-macosx13.0" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement \
  "$ROOT/Sources/main.swift" "$ROOT/Sources/Ports.swift" "$ROOT/Sources/Panel.swift" \
  -o "$APP/Contents/MacOS/PortPocket"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/PortPocket.icns" ]]; then cp "$ROOT/Resources/PortPocket.icns" "$APP/Contents/Resources/"; fi
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/PortPocket" --self-test
printf '\nBuilt: %s\n' "$APP"
