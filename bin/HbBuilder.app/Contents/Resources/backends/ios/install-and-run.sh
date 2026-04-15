#!/usr/bin/env bash
# install-and-run.sh - Install and run an iOS .app on the simulator
#
# Usage:
#   install-and-run.sh [app_path] [device_name]
#     app_path    : path to .app bundle (default: /tmp/HarbouriOS/app-build/HarbourApp.app)
#     device_name : simulator name (default: iPhone 16)

set -eu

APP_PATH="${1:-/tmp/HarbouriOS/app-build/HarbourApp.app}"
DEVICE="${2:-iPhone 16}"
BUNDLE_ID="com.harbour.builder.app"

# Find the device UDID
UDID=$(xcrun simctl list devices available | grep "$DEVICE" | head -1 | grep -o -E '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')

if [ -z "$UDID" ]; then
  echo "ERROR: Simulator '$DEVICE' not found."
  echo "Available devices:"
  xcrun simctl list devices available | grep iPhone
  exit 1
fi

# Boot the simulator if not already running
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

# Wait for simulator to be ready
echo "Waiting for simulator to boot..."
sleep 3

# Install the app
echo "Installing $APP_PATH..."
xcrun simctl install booted "$APP_PATH"

# Launch the app
echo "Launching $BUNDLE_ID..."
xcrun simctl launch booted "$BUNDLE_ID"

echo "=============================================="
echo " App running on $DEVICE"
echo " To view logs: xcrun simctl spawn booted log stream --process HarbourApp"
echo "=============================================="
