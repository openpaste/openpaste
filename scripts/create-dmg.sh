#!/bin/bash
set -euo pipefail

# Create DMG for OpenPaste distribution
# Usage: ./scripts/create-dmg.sh [path/to/OpenPaste.app] [output-dir]

APP_PATH="${1:-build/Build/Products/Release/OpenPaste.app}"
OUTPUT_DIR="${2:-.}"
APP_NAME="OpenPaste"
VERSION=$(defaults read "$(pwd)/${APP_PATH}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "0.0.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
TEMP_DIR=$(mktemp -d)

echo "==> Creating DMG for ${APP_NAME} v${VERSION}"
echo "    App: ${APP_PATH}"
echo "    Output: ${DMG_PATH}"

# Verify app exists
if [ ! -d "${APP_PATH}" ]; then
    echo "ERROR: ${APP_PATH} not found"
    exit 1
fi

# Create DMG layout
mkdir -p "${TEMP_DIR}/${APP_NAME}"
cp -R "${APP_PATH}" "${TEMP_DIR}/${APP_NAME}/"
ln -s /Applications "${TEMP_DIR}/${APP_NAME}/Applications"

# Create DMG
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${TEMP_DIR}/${APP_NAME}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_PATH}"

# Cleanup
rm -rf "${TEMP_DIR}"

echo "==> DMG created: ${DMG_PATH}"
echo "    SHA-256: $(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
