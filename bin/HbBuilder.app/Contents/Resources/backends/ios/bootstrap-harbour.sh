#!/usr/bin/env bash
# Harbour for iOS - cross-compile from macOS
#
# Prerequisites:
#   - Xcode installed with iOS SDK
#   - Native macOS Harbour already built (for host hbmk2/harbour bootstrap)
#   - GNU make
#
# Usage:
#   ./bootstrap-harbour.sh                     # build arm64 device (default)
#   TARGET=simulator ./bootstrap-harbour.sh    # build x86_64 for simulator
#   CLEAN=1 ./bootstrap-harbour.sh             # make clean first

set -eu

# ---------- configurable ----------
: "${HARBOUR_SRC:=/Users/usuario/harbour-ios-src}"
: "${HARBOUR_HOST:=/Users/usuario/harbour/bin}"
: "${TARGET:=device}"
: "${JOBS:=8}"
# ----------------------------------

case "$TARGET" in
  device)
    ABI=arm64
    TRIPLE=arm64-apple-ios14.0
    SDK=iphoneos
    BUILD_NAME=-ios-arm64
    ;;
  simulator)
    ABI=x86_64
    TRIPLE=x86_64-apple-ios14.0-simulator
    SDK=iphonesimulator
    BUILD_NAME=-ios-sim-x86_64
    ;;
  *)
    echo "Unknown TARGET: $TARGET (use 'device' or 'simulator')" >&2
    exit 1
    ;;
esac

SDK_PATH=$(xcrun --sdk "$SDK" --show-sdk-path)

# --- sanity checks ---
[ -d "$HARBOUR_SRC" ]     || { echo "Harbour src not found at $HARBOUR_SRC"; exit 1; }
[ -f "$HARBOUR_HOST/harbour" ] || { echo "Host harbour not found at $HARBOUR_HOST"; exit 1; }
[ -d "$SDK_PATH" ]        || { echo "iOS SDK not found at $SDK_PATH"; exit 1; }

echo "=============================================="
echo " Harbour for iOS build"
echo "=============================================="
echo " Target    : $TARGET ($ABI)"
echo " SDK       : $SDK_PATH"
echo " Host HB   : $HARBOUR_HOST"
echo " Src       : $HARBOUR_SRC"
echo " Jobs      : $JOBS"
echo "=============================================="

# --- environment for the Harbour build system ---
export HB_PLATFORM=darwin
export HB_COMPILER=clang
export HB_BUILD_STRIP=all
export HB_BUILD_CONTRIBS=no
export HB_BUILD_DYN=no
export HB_BUILD_SHARED=no
export HB_BUILD_PARTS=lib
export HB_BUILD_NAME="$BUILD_NAME"
export HB_HOST_BIN="$HARBOUR_HOST"
export PATH="$HARBOUR_HOST:$PATH"

# Compiler overrides for iOS cross-compilation
export HB_CCPATH=$(xcrun --sdk "$SDK" --find clang | xargs dirname)/
export HB_CCPREFIX=""
export HB_CC="clang -target $TRIPLE -isysroot $SDK_PATH"
export HB_CXX="clang++ -target $TRIPLE -isysroot $SDK_PATH"
export HB_USER_CFLAGS="-target $TRIPLE -isysroot $SDK_PATH -fPIC"
export HB_USER_LDFLAGS="-target $TRIPLE -isysroot $SDK_PATH"

cd "$HARBOUR_SRC"

if [ "${CLEAN:-0}" = "1" ]; then
  echo ">>> make clean"
  make clean || true
fi

echo ">>> make -j$JOBS"
make -j"$JOBS"

echo
echo "=============================================="
echo " Build finished. Look for libs under:"
echo "   $HARBOUR_SRC/lib/darwin/clang$BUILD_NAME/"
echo "=============================================="
