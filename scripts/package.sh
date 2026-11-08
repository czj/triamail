#!/usr/bin/env bash
# Builds Triamail.app in Release and packages it for distribution:
#   dist/Triamail-<version>.zip  archive read by Sparkle (appcast)
#   Triamail.zip, Triamail.dmg   stable names for the "latest" download links (README, Homebrew)
#
# Usage: scripts/package.sh <version> [build number]
#
# Optional environment:
#   SPARKLE_PUBLIC_KEY                    EdDSA public key; empty = updates off
#   DEVELOPER_ID                          e.g. "Developer ID Application: …" (already in the keychain);
#                                         empty = ad hoc signature
#   APPLE_ID, APPLE_APP_PASSWORD, APPLE_TEAM_ID
#                                         notarization (only with DEVELOPER_ID)
set -euo pipefail

VERSION=${1:?usage: scripts/package.sh <version> [build number]}
BUILD=${2:-1}
cd "$(dirname "$0")/.."

rm -rf build build.log dist Triamail.zip Triamail.dmg
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate

xcodebuild -project Triamail.xcodeproj -scheme Triamail -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
  SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}" build > build.log 2>&1 \
  || { grep -E ": error: " build.log | sort -u; tail -40 build.log; exit 1; }

APP=build/Build/Products/Release/Triamail.app
[ -d "$APP" ] || { echo "Triamail.app not found"; exit 1; }

if [ -n "${DEVELOPER_ID:-}" ]; then
  # Re-sign inside out (Sparkle's nested helpers first), hardened runtime and timestamp, as notarization requires.
  sign() { codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$@"; }
  SPARKLE=$APP/Contents/Frameworks/Sparkle.framework/Versions/B
  sign "$SPARKLE/XPCServices/Installer.xpc"
  sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
  sign "$SPARKLE/Autoupdate"
  sign "$SPARKLE/Updater.app"
  sign "$APP/Contents/Frameworks/Sparkle.framework"
  sign --preserve-metadata=entitlements "$APP"
fi
codesign --verify --deep --strict "$APP"

# Disk image: the app next to a link to /Applications, to drag and drop.
STAGE=$(mktemp -d)
ditto "$APP" "$STAGE/Triamail.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Triamail -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov Triamail.dmg
rm -rf "$STAGE"

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" Triamail.dmg
  if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
    # Notarizing the disk image also notarizes the app inside it: both can then be stapled.
    xcrun notarytool submit Triamail.dmg --wait \
      --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID"
    xcrun stapler staple Triamail.dmg
    xcrun stapler staple "$APP"
  fi
fi

mkdir -p dist
ditto -c -k --keepParent "$APP" "dist/Triamail-$VERSION.zip"
cp "dist/Triamail-$VERSION.zip" Triamail.zip
ls -lh dist Triamail.zip Triamail.dmg
