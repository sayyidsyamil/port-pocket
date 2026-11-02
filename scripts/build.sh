#!/bin/bash
# Builds a universal (arm64 + x86_64) Port Pocket.app.
#
# Signing is controlled by CODESIGN_IDENTITY:
#   unset or "-"  ad-hoc signature (works locally, Gatekeeper prompts on download)
#   "Developer ID Application: ..."  hardened runtime + secure timestamp
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Port Pocket.app"
BIN="$APP/Contents/MacOS/PortPocket"
ENTITLEMENTS="$ROOT/Resources/PortPocket.entitlements"
MIN_MACOS="13.0"
IDENTITY="${CODESIGN_IDENTITY:--}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for arch in arm64 x86_64; do
  swiftc -swift-version 5 -O -target "$arch-apple-macosx$MIN_MACOS" \
    -framework AppKit -framework SwiftUI -framework ServiceManagement \
    "$ROOT/Sources/main.swift" "$ROOT/Sources/Ports.swift" "$ROOT/Sources/Panel.swift" \
    -o "$WORK/PortPocket-$arch"
done
lipo -create "$WORK/PortPocket-arm64" "$WORK/PortPocket-x86_64" -output "$BIN"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/PortPocket.icns" ]]; then
  cp "$ROOT/Resources/PortPocket.icns" "$APP/Contents/Resources/"
fi

if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP"
else
  codesign --force --sign "$IDENTITY" --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" "$APP"
fi
codesign --verify --deep --strict "$APP"

archs="$(lipo -archs "$BIN")"
grep -q arm64 <<<"$archs"
grep -q x86_64 <<<"$archs"

"$BIN" --self-test
printf '\nBuilt universal (%s), identity %s: %s\n' "$archs" "$IDENTITY" "$APP"
