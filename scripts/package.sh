#!/bin/bash
# Builds a universal Pressly.app and packages it into dist/:
#   Pressly-<version>.pkg, Pressly-<version>.dmg, Pressly-<version>.zip (pkg + guide), How to Install.txt
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL=1 ./scripts/build-app.sh release
ARCHS=$(lipo -archs build/Pressly.app/Contents/MacOS/Pressly)
case "$ARCHS" in *arm64*x86_64*|*x86_64*arm64*) ;; *) echo "Expected a universal binary, got: $ARCHS"; exit 1;; esac

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
GUIDE="installer/How to Install.txt"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root/Applications" dist
ditto build/Pressly.app "$WORK/root/Applications/Pressly.app"

# Always install into /Applications, even if another copy exists elsewhere on the Mac.
pkgbuild --analyze --root "$WORK/root" "$WORK/components.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$WORK/components.plist"
pkgbuild --root "$WORK/root" --component-plist "$WORK/components.plist" --scripts installer/scripts \
  --identifier app.pressly.Pressly.pkg --version "$VERSION" --install-location / \
  "$WORK/Pressly-component.pkg" >/dev/null

cat > "$WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Pressly</title>
    <welcome file="welcome.html" mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_localSystem="true"/>
    <volume-check><allowed-os-versions><os-version min="14.0"/></allowed-os-versions></volume-check>
    <choices-outline><line choice="default"><line choice="app"/></line></choices-outline>
    <choice id="default"/>
    <choice id="app" visible="false"><pkg-ref id="app.pressly.Pressly.pkg"/></choice>
    <pkg-ref id="app.pressly.Pressly.pkg" version="$VERSION" onConclusion="none">Pressly-component.pkg</pkg-ref>
</installer-gui-script>
XML

PKG="dist/Pressly-$VERSION.pkg"
rm -f "$PKG"
productbuild --distribution "$WORK/distribution.xml" --resources installer/resources --package-path "$WORK" "$PKG" >/dev/null
echo "Created $(pwd)/$PKG ($(du -h "$PKG" | cut -f1))"

cp "$GUIDE" "dist/How to Install.txt"

ZIPDIR="$WORK/Pressly-$VERSION"
mkdir -p "$ZIPDIR"
cp "$PKG" "$GUIDE" "$ZIPDIR/"
ZIP="dist/Pressly-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --norsrc --noextattr --keepParent "$ZIPDIR" "$ZIP"
echo "Created $(pwd)/$ZIP (installer + How to Install.txt)"

STAGE="$WORK/dmg"
mkdir -p "$STAGE"
ditto build/Pressly.app "$STAGE/Pressly.app"
ln -s /Applications "$STAGE/Applications"
cp "$GUIDE" "$STAGE/"
DMG="dist/Pressly-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Pressly" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
echo "Created $(pwd)/$DMG ($(du -h "$DMG" | cut -f1))"
