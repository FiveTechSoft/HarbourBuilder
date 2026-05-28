#!/bin/bash
# notarize_mac.sh — Sign, notarize, and staple HbBuilder.app for distribution.
#
# Prerequisites:
#   1. Apple Developer Program membership ($99/yr)
#   2. "Developer ID Application" certificate in Keychain
#   3. App-specific password at appleid.apple.com → Security → App Passwords
#
# Usage:
#   APPLE_ID="you@example.com" \
#   APPLE_TEAM_ID="ABCDE12345" \
#   APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
#   ./notarize_mac.sh
#
# Optional: set APP_PATH to override default bin/HbBuilder.app

set -euo pipefail

APP_PATH="${APP_PATH:-$(dirname "$0")/bin/HbBuilder.app}"
ENTITLEMENTS="$(dirname "$0")/resources/HbBuilder.entitlements"
SIGN_IDENTITY="Developer ID Application: ${APPLE_TEAM_ID:-}"

if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ] || [ -z "${APPLE_APP_PASSWORD:-}" ]; then
    echo "ERROR: Set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_PASSWORD before running."
    echo "  export APPLE_ID=you@example.com"
    echo "  export APPLE_TEAM_ID=ABCDE12345"
    echo "  export APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx"
    exit 1
fi

# Resolve full signing identity from keychain
FULL_IDENTITY=$(security find-identity -v -p codesigning \
    | grep "Developer ID Application" | grep "${APPLE_TEAM_ID}" \
    | head -1 | sed 's/.*"\(.*\)"/\1/')

if [ -z "$FULL_IDENTITY" ]; then
    echo "ERROR: No 'Developer ID Application' certificate found for team ${APPLE_TEAM_ID}."
    echo "Download it from developer.apple.com → Certificates, IDs & Profiles."
    exit 1
fi

echo "Identity: $FULL_IDENTITY"
echo "App:      $APP_PATH"

# --- 1. Sign ---
echo "[1/4] Signing..."
codesign --deep --force --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$FULL_IDENTITY" \
    --timestamp \
    "$APP_PATH"

codesign --verify --deep --strict "$APP_PATH"
echo "      Signature OK"

# --- 2. Zip for submission ---
ZIP_PATH="${APP_PATH%.app}-notarize.zip"
echo "[2/4] Creating $ZIP_PATH..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# --- 3. Submit for notarization ---
echo "[3/4] Submitting to Apple notary service (may take a few minutes)..."
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

# --- 4. Staple ---
echo "[4/4] Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

rm -f "$ZIP_PATH"

echo ""
echo "Done. $APP_PATH is signed, notarized, and stapled."
echo "Package for distribution:"
echo "  ditto -c -k --keepParent bin/HbBuilder.app HbBuilder-macos-arm64.zip"
