#!/bin/bash
# Builds Pressly.app into ./build. Pass UNIVERSAL=1 for an Apple silicon + Intel binary.
# Uses Xcode's toolchain: the Command Line Tools can't expand SwiftUI macros on the macOS 27 SDK.
set -euo pipefail
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; fi
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
ARCH_ARGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then ARCH_ARGS=(--arch arm64 --arch x86_64); fi
swift build -c "$CONFIG" ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"}
BIN_DIR=$(swift build -c "$CONFIG" ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"} --show-bin-path)
APP="build/Pressly.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Pressly" "$APP/Contents/MacOS/Pressly"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Pressly.sdef "$APP/Contents/Resources/Pressly.sdef"
ditto Resources/Recordings "$APP/Contents/Resources/Recordings"
if [ ! -f Resources/AppIcon.icns ]; then
  TMP=$(mktemp -d)
  swift scripts/make-icon.swift "$TMP/AppIcon.iconset"
  iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
  rm -rf "$TMP"
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
if [ "$CONFIG" = "release" ]; then strip -x "$APP/Contents/MacOS/Pressly"; fi

# Sign with a stable local certificate so the Accessibility permission survives rebuilds
# (run scripts/make-signing.sh once). Falls back to ad-hoc signing.
KC="$(pwd)/signing/pressly.keychain-db"
if [ -f "$KC" ] && [ -f signing/keychain-password.txt ]; then
  security unlock-keychain -p "$(cat signing/keychain-password.txt)" "$KC"
  ID=$(security find-identity "$KC" | awk '/Pressly Local Signing/ {print $2; exit}')
  codesign --force --keychain "$KC" --sign "$ID" -i app.pressly.Pressly "$APP"
  echo "Signed with Pressly Local Signing"
else
  codesign --force --sign - -i app.pressly.Pressly "$APP"
  echo "Warning: ad-hoc signed; permissions reset on every rebuild (run scripts/make-signing.sh once)"
fi
echo "Built $APP"
