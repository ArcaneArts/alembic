#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="${1:-$(grep '^version:' "$ROOT/pubspec.yaml" | sed -E 's/^version:[[:space:]]*//')}"
OUT="${2:-$ROOT/release}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
MACOS_SKIP_SIGNING="${MACOS_SKIP_SIGNING:-1}"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  if [[ -x /Users/brianfopiano/Developer/flutter/bin/flutter ]]; then
    FLUTTER_BIN=/Users/brianfopiano/Developer/flutter/bin/flutter
  fi
fi

mkdir -p "$OUT"
rm -f "$OUT/Alembic-$VERSION-macos-universal.zip" "$OUT/Alembic-$VERSION-macos.dmg"

cd "$ROOT"
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build macos --release --config-only
xcodebuild \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -derivedDataPath build/macos \
  -destination platform=macOS \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  build

APP_SOURCE="$ROOT/build/macos/Build/Products/Release/Alembic.app"
if [[ ! -d "$APP_SOURCE" ]]; then
  APP_SOURCE="$ROOT/build/macos/Build/Products/Release/alembic.app"
fi
if [[ ! -d "$APP_SOURCE" ]]; then
  echo "Could not find built Alembic.app" >&2
  exit 1
fi

STAGE="$ROOT/build/release/macos"
DMG_STAGE="$ROOT/build/release/dmg"
APP_STAGE="$STAGE/Alembic.app"
rm -rf "$STAGE" "$DMG_STAGE"
mkdir -p "$STAGE" "$DMG_STAGE"
cp -R "$APP_SOURCE" "$APP_STAGE"

if [[ "${MACOS_SKIP_SIGNING:-}" != "1" ]]; then
  if [[ -z "${MACOS_CODESIGN_IDENTITY:-}" ]]; then
    echo "MACOS_CODESIGN_IDENTITY is required unless MACOS_SKIP_SIGNING=1" >&2
    exit 1
  fi
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, and APPLE_TEAM_ID are required unless MACOS_SKIP_SIGNING=1" >&2
    exit 1
  fi
  codesign --deep --force --options runtime --timestamp --sign "$MACOS_CODESIGN_IDENTITY" "$APP_STAGE"
  codesign --verify --deep --strict "$APP_STAGE"
  NOTARY_ZIP="$ROOT/build/release/Alembic-notary.zip"
  rm -f "$NOTARY_ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP_STAGE" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
  xcrun stapler staple "$APP_STAGE"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_STAGE" "$OUT/Alembic-$VERSION-macos-universal.zip"
cp -R "$APP_STAGE" "$DMG_STAGE/Alembic.app"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname Alembic -srcfolder "$DMG_STAGE" -ov -format UDZO "$OUT/Alembic-$VERSION-macos.dmg"

if [[ "${MACOS_SKIP_SIGNING:-}" != "1" ]]; then
  xcrun notarytool submit "$OUT/Alembic-$VERSION-macos.dmg" --apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
  xcrun stapler staple "$OUT/Alembic-$VERSION-macos.dmg"
fi
