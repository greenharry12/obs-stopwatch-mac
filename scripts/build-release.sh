#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <version> <arm64|x86_64>" >&2
    exit 64
fi

VERSION="$1"
ARCH="$2"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must use semantic version format, for example 1.0.0." >&2
    exit 64
fi

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
    echo "Architecture must be arm64 or x86_64." >&2
    exit 64
fi

HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" != "$ARCH" ]]; then
    echo "Requested $ARCH build must run on a native $ARCH host; current host is $HOST_ARCH." >&2
    exit 65
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OBS Stopwatch"
EXECUTABLE_NAME="OBSStopwatchMac"
BUNDLE_ID="${APPLE_BUNDLE_ID:-cc.myrtle.obs-stopwatch}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARIZE="${NOTARIZE:-false}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
BUILD_ROOT="$ROOT/.build/release-package-$ARCH"
SWIFT_BUILD_DIR="$BUILD_ROOT/swift"
ICONSET="$BUILD_ROOT/AppIcon.iconset"
APP_BUNDLE="$BUILD_ROOT/$APP_NAME.app"
DMG_STAGING="$BUILD_ROOT/dmg"
DMG_PATH="$OUTPUT_DIR/OBS-Stopwatch-$VERSION-$ARCH.dmg"
SOURCE_ICON="$ROOT/Assets/AppIcon.png"

if [[ ! -f "$SOURCE_ICON" ]]; then
    echo "Missing icon source: $SOURCE_ICON" >&2
    exit 66
fi

if [[ "$NOTARIZE" == "true" && -z "$SIGNING_IDENTITY" ]]; then
    echo "NOTARIZE=true requires SIGNING_IDENTITY." >&2
    exit 64
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$ICONSET" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$DMG_STAGING" "$OUTPUT_DIR"

sips -z 16 16 "$SOURCE_ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$SOURCE_ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SOURCE_ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$SOURCE_ICON" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

swift build \
    --package-path "$ROOT" \
    --configuration release \
    --scratch-path "$SWIFT_BUILD_DIR"

BIN_PATH="$(swift build \
    --package-path "$ROOT" \
    --configuration release \
    --scratch-path "$SWIFT_BUILD_DIR" \
    --show-bin-path)/$EXECUTABLE_NAME"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>OBS Stopwatch</string>
  <key>CFBundleExecutable</key>
  <string>OBSStopwatchMac</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>OBS Stopwatch</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$APP_BUNDLE/Contents/Info.plist"

BINARY_ARCHS="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME")"
if [[ "$BINARY_ARCHS" != "$ARCH" ]]; then
    echo "Expected a single $ARCH binary, found: $BINARY_ARCHS" >&2
    exit 65
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    codesign \
        --force \
        --timestamp \
        --options runtime \
        --sign "$SIGNING_IDENTITY" \
        "$APP_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -format UDZO \
    -ov \
    "$DMG_PATH"

if [[ -n "$SIGNING_IDENTITY" ]]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    codesign --verify --strict --verbose=2 "$DMG_PATH"
fi

if [[ "$NOTARIZE" == "true" ]]; then
    : "${APPLE_API_KEY_PATH:?APPLE_API_KEY_PATH is required for notarization}"
    : "${APPLE_API_KEY_ID:?APPLE_API_KEY_ID is required for notarization}"
    : "${APPLE_API_ISSUER_ID:?APPLE_API_ISSUER_ID is required for notarization}"

    xcrun notarytool submit "$DMG_PATH" \
        --key "$APPLE_API_KEY_PATH" \
        --key-id "$APPLE_API_KEY_ID" \
        --issuer "$APPLE_API_ISSUER_ID" \
        --wait

    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    codesign --verify --strict --verbose=2 "$DMG_PATH"
    spctl --assess \
        --type open \
        --context context:primary-signature \
        --verbose=2 \
        "$DMG_PATH"
fi

echo "Created $DMG_PATH"
