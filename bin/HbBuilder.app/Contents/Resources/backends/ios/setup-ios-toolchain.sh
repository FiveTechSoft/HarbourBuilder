#!/usr/bin/env bash
# setup-ios-toolchain.sh
#
# Verifies that the iOS development toolchain is properly installed.
# On macOS with Xcode, most components are already present.
# This script checks for missing pieces and installs them if needed.
#
# Components checked:
#   1. Xcode command line tools
#   2. iOS SDK (device)
#   3. iOS Simulator runtime
#   4. Harbour-for-iOS libs (built via bootstrap-harbour.sh)
#
# Usage:
#   ./setup-ios-toolchain.sh

set -u

on_exit() {
  local rc=$?
  echo
  echo "============================================================"
  echo " setup-ios-toolchain finished (exit code $rc)"
  echo "============================================================"
}
trap on_exit EXIT

# ---------- configurable paths ----------
HB_REPO=/Users/usuario/HarbourBuilder
HB_IOS_LIB_ZIP="$HB_REPO/releases/harbour-ios-arm64.zip"
HB_IOS_ROOT=/Users/usuario/harbour-ios-src

banner() {
  echo
  echo "============================================================"
  echo " $*"
  echo "============================================================"
}

have_xcode()    { [ -d "/Applications/Xcode.app" ]; }
have_clt()      { xcode-select -p &>/dev/null; }
have_ios_sdk()  { xcrun --sdk iphoneos --show-sdk-path &>/dev/null; }
have_sim_runtime() { [ -n "$(xcrun simctl list runtimes 2>/dev/null | grep iOS)" ]; }
have_hb_ios()   { [ -d "$HB_IOS_ROOT/lib/darwin/clang-ios-arm64" ]; }

# ---------- 1. Xcode ----------
if ! have_xcode; then
  banner "1/4  Xcode - NOT FOUND"
  echo "Please install Xcode from the Mac App Store."
  echo "This is required for iOS development."
  exit 1
else
  echo "[OK] Xcode installed: $(xcodebuild -version 2>/dev/null | head -1)"
fi

# ---------- 2. Command Line Tools ----------
if ! have_clt; then
  banner "2/4  Command Line Tools - installing"
  xcode-select --install
  echo "Please follow the installer prompts, then re-run this script."
  exit 1
else
  echo "[OK] Command Line Tools: $(xcode-select -p)"
fi

# ---------- 3. iOS SDK ----------
if ! have_ios_sdk; then
  banner "3/4  iOS SDK - NOT FOUND"
  echo "Open Xcode > Settings > Platforms and install the iOS platform."
  exit 1
else
  SDK_VER=$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null)
  echo "[OK] iOS SDK: $(xcrun --sdk iphoneos --show-sdk-path) ($SDK_VER)"
fi

# ---------- 4. iOS Simulator Runtime ----------
if ! have_sim_runtime; then
  banner "4/5  iOS Simulator Runtime - downloading"
  echo "Installing iOS Simulator runtime..."
  xcodebuild -downloadPlatform iOS
  if have_sim_runtime; then
    echo "[OK] iOS Simulator installed"
  else
    echo "[WARN] iOS Simulator may need manual install via Xcode > Settings > Platforms"
  fi
else
  SIM_VER=$(xcrun simctl list runtimes 2>/dev/null | grep iOS | head -1 | awk '{print $NF}')
  echo "[OK] iOS Simulator runtime: $SIM_VER"
fi

# ---------- 5. Harbour-for-iOS libs ----------
if ! have_hb_ios; then
  banner "5/5  Harbour-for-iOS libs - building"
  if [ ! -d "$HB_IOS_ROOT" ]; then
    echo "Cloning Harbour source..."
    git clone --depth 1 https://github.com/harbour/core.git "$HB_IOS_ROOT"
  fi

  echo "Building Harbour for iOS (arm64 device)..."
  "$HB_REPO/source/backends/ios/bootstrap-harbour.sh"

  echo "Building Harbour for iOS (x86_64 simulator)..."
  TARGET=simulator "$HB_REPO/source/backends/ios/bootstrap-harbour.sh"

  if have_hb_ios; then
    echo "[OK] Harbour iOS libs built"
  else
    echo "[ERROR] Harbour iOS build failed"
    exit 1
  fi
else
  echo "[OK] Harbour iOS libs: $HB_IOS_ROOT/lib/darwin/clang-ios-arm64/"
fi

banner "All done. You can now Run > Run on iOS from the IDE."
