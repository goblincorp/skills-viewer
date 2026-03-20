#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SkillsViewer"
BUNDLE_NAME="$APP_NAME.app"
BUILD_DIR="build"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SIGN_IDENTITY=""
NOTARIZE=false
APPLE_ID=""
TEAM_ID=""
PASSWORD=""
CREATE_DMG=false
UNIVERSAL=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build a distributable .app bundle for $APP_NAME.

Options:
  --sign IDENTITY     Code signing identity (e.g. "Developer ID Application: ...")
  --notarize          Submit for notarization (implies --dmg)
  --apple-id ID       Apple ID for notarization
  --team-id TEAMID    Team ID for notarization
  --password SPEC     App-specific password (e.g. @keychain:AC_PASSWORD)
  --dmg               Create DMG
  --universal         Build universal binary (arm64 + x86_64)
  -h, --help          Show this help
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sign)      SIGN_IDENTITY="$2"; shift 2 ;;
        --notarize)  NOTARIZE=true; CREATE_DMG=true; shift ;;
        --apple-id)  APPLE_ID="$2"; shift 2 ;;
        --team-id)   TEAM_ID="$2"; shift 2 ;;
        --password)  PASSWORD="$2"; shift 2 ;;
        --dmg)       CREATE_DMG=true; shift ;;
        --universal) UNIVERSAL=true; shift ;;
        -h|--help)   usage ;;
        *)           echo "Unknown option: $1"; usage ;;
    esac
done

if $NOTARIZE; then
    if [[ -z "$SIGN_IDENTITY" || -z "$APPLE_ID" || -z "$TEAM_ID" || -z "$PASSWORD" ]]; then
        echo "Error: --notarize requires --sign, --apple-id, --team-id, and --password"
        exit 1
    fi
fi

cd "$PROJECT_DIR"

# --- Build ---
echo "==> Building $APP_NAME (release)..."

if $UNIVERSAL; then
    swift build -c release --arch arm64
    swift build -c release --arch x86_64
    ARM_BIN=".build/arm64-apple-macosx/release/$APP_NAME"
    X86_BIN=".build/x86_64-apple-macosx/release/$APP_NAME"
    RELEASE_BIN="$BUILD_DIR/$APP_NAME-universal"
    mkdir -p "$BUILD_DIR"
    echo "==> Creating universal binary with lipo..."
    lipo -create "$ARM_BIN" "$X86_BIN" -output "$RELEASE_BIN"
else
    swift build -c release
    RELEASE_BIN=".build/release/$APP_NAME"
fi

# --- Create .app bundle ---
echo "==> Creating $BUNDLE_NAME..."
APP_PATH="$BUILD_DIR/$BUNDLE_NAME"
CONTENTS="$APP_PATH/Contents"

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp "$RELEASE_BIN" "$CONTENTS/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

echo "    $APP_PATH"

# --- Code sign ---
if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "==> Signing with: $SIGN_IDENTITY"
    codesign --force --sign "$SIGN_IDENTITY" \
        --entitlements "Resources/$APP_NAME.entitlements" \
        --options runtime \
        --timestamp \
        "$APP_PATH"
    echo "==> Verifying signature..."
    codesign --verify --deep --strict "$APP_PATH"
fi

# --- Create DMG ---
DMG_PATH=""
if $CREATE_DMG; then
    DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
    echo "==> Creating DMG..."
    rm -f "$DMG_PATH"
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$APP_PATH" \
        -ov -format UDZO \
        "$DMG_PATH"

    if [[ -n "$SIGN_IDENTITY" ]]; then
        echo "==> Signing DMG..."
        codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
    fi

    echo "    $DMG_PATH"
fi

# --- Notarize ---
if $NOTARIZE; then
    echo "==> Submitting for notarization..."
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$PASSWORD" \
        --wait

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"
fi

echo "==> Done!"
